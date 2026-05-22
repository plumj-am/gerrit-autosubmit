use std::{
   collections::HashMap,
   env,
   time::Duration,
};

use anyhow::{
   Context as _,
   Result,
   anyhow,
};
use base64::Engine as _;
use serde::Deserialize;
use serde_json::Value;
use ureq::Agent;

pub struct Config {
   pub gerrit_url: String,
   pub username:   String,
   pub password:   String,
   pub interval:   u64,
   pub agent:      Agent,
}

impl Config {
   pub fn from_env() -> Result<Self> {
      Ok(Self {
         gerrit_url: env::var("GERRIT_URL")
            .context("Gerrit base URL (no trailing slash) must be set in GERRIT_URL")?,
         username:   env::var("GERRIT_USERNAME")
            .context("Gerrit username must be set in GERRIT_USERNAME")?,
         password:   env::var("GERRIT_PASSWORD")
            .context("Gerrit password must be set in GERRIT_PASSWORD")?,
         interval:   env::var("GERRIT_POLL_INTERVAL_SECS")
            .ok()
            .and_then(|v| v.parse().ok())
            .unwrap_or(30),
         agent:      Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(30)))
            .user_agent("gerrit-autosubmit")
            .build()
            .new_agent(),
      })
   }
}

#[derive(Deserialize)]
pub struct ChangeInfo {
   pub id:        String,
   pub revisions: HashMap<String, Value>,
}

#[derive(Deserialize)]
pub struct Action {
   #[serde(default)]
   pub enabled: bool,
}

const GERRIT_RESPONSE_PREFIX: &str = ")]}'";

fn request_err(e: ureq::Error, context: &str) -> anyhow::Error {
   match e {
      ureq::Error::StatusCode(code) => anyhow!("{context} with status {code}"),
      e => anyhow!("{context}: {e}"),
   }
}

fn auth_header(username: &str, password: &str) -> String {
   let creds = base64::engine::general_purpose::STANDARD.encode(format!("{username}:{password}"));
   format!("Basic {creds}")
}

pub fn get<T>(cfg: &Config, endpoint: &str) -> Result<T>
where
   T: serde::de::DeserializeOwned,
{
   let url = format!("{}/a{}", cfg.gerrit_url, endpoint);
   let response = cfg
      .agent
      .get(&url)
      .header("Authorization", &auth_header(&cfg.username, &cfg.password))
      .call()
      .map_err(|e| request_err(e, "request failed"))?;

   let body = response.into_body().read_to_string()?;
   let result: T = serde_json::from_str(&body[GERRIT_RESPONSE_PREFIX.len()..])?;
   Ok(result)
}

pub fn submit(cfg: &Config, change_id: &str) -> Result<()> {
   let url = format!("{}/a/changes/{}/submit", cfg.gerrit_url, change_id);
   cfg.agent
      .post(&url)
      .header("Authorization", &auth_header(&cfg.username, &cfg.password))
      .send_empty()
      .map_err(|e| request_err(e, "submit failed"))?;

   Ok(())
}
