use std::{
   collections::HashMap,
   env,
};

use anyhow::{
   Context,
   Result,
   anyhow,
};
use serde::Deserialize;
use serde_json::Value;

pub struct Config {
   gerrit_url: String,
   username:   String,
   password:   String,
}

impl Config {
   pub fn from_env() -> Result<Self> {
      Ok(Config {
         gerrit_url: env::var("GERRIT_URL")
            .context("Gerrit base URL (no trailing slash) must be set in GERRIT_URL")?,
         username:   env::var("GERRIT_USERNAME")
            .context("Gerrit username must be set in GERRIT_USERNAME")?,
         password:   env::var("GERRIT_PASSWORD")
            .context("Gerrit password must be set in GERRIT_PASSWORD")?,
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

pub fn get<T: serde::de::DeserializeOwned>(cfg: &Config, endpoint: &str) -> Result<T> {
   let response = crimp::Request::get(&format!("{}/a{}", cfg.gerrit_url, endpoint))
      .user_agent("gerrit-autosubmit")?
      .basic_auth(&cfg.username, &cfg.password)?
      .send()?
      .error_for_status(|r| anyhow!("request failed with status {}", r.status))?;

   let result: T = serde_json::from_slice(&response.body[GERRIT_RESPONSE_PREFIX.len()..])?;
   Ok(result)
}

pub fn submit(cfg: &Config, change_id: &str) -> Result<()> {
   crimp::Request::post(&format!(
      "{}/a/changes/{}/submit",
      cfg.gerrit_url, change_id
   ))
   .user_agent("gerrit-autosubmit")?
   .basic_auth(&cfg.username, &cfg.password)?
   .send()?
   .error_for_status(|r| anyhow!("submit failed with status {}", r.status))?;

   Ok(())
}
