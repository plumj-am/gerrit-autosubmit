//! gerrit-autosubmit connects to a Gerrit instance and submits the
//! longest chain of changes in which all ancestors are ready and
//! marked for autosubmit.
//!
//! It works like this:
//!
//! * fetches all changes the Gerrit query API considers submittable (i.e. all
//!   requirements fulfilled), and that have the `Autosubmit` label set
//!
//! * filters these changes down to those that are _actually_ submittable (in
//!   Gerrit API terms: that have an active Submit button)
//!
//! * filters out those that would submit ancestors that are *not* marked with
//!   the `Autosubmit` label
//!
//! * submits the longest chain
//!
//! * loops

use std::{
   collections::{
      BTreeMap,
      HashMap,
      HashSet,
   },
   thread,
   time,
};

use anyhow::{
   Context,
   Result,
};

pub mod gerrit;

#[derive(Debug)]
struct SubmittableChange {
   id:       String,
   revision: String,
}

fn list_submittable(cfg: &gerrit::Config) -> Result<Vec<SubmittableChange>> {
   let mut out = Vec::new();

   let changes: Vec<gerrit::ChangeInfo> = gerrit::get(
      cfg,
      "/changes/?q=is:submittable+label:Autosubmit+-is:wip+is:open&o=SKIP_DIFFSTAT&\
       o=CURRENT_REVISION",
   )
   .context("failed to list submittable changes")?;

   for change in changes.into_iter() {
      out.push(SubmittableChange {
         id:       change.id,
         revision: change
            .revisions
            .into_keys()
            .next()
            .context("change had no current revision")?,
      });
   }

   Ok(out)
}

fn is_submittable(cfg: &gerrit::Config, change: &SubmittableChange) -> Result<bool> {
   let response: HashMap<String, gerrit::Action> = gerrit::get(
      cfg,
      &format!(
         "/changes/{}/revisions/{}/actions",
         change.id, change.revision
      ),
   )
   .context("failed to fetch actions for change")?;

   match response.get("submit") {
      None => Ok(false),
      Some(action) => Ok(action.enabled),
   }
}

fn submitted_with(cfg: &gerrit::Config, change_id: &str) -> Result<HashSet<String>> {
   let response: Vec<gerrit::ChangeInfo> =
      gerrit::get(cfg, &format!("/changes/{}/submitted_together", change_id))
         .context("failed to fetch related change list")?;

   Ok(response.into_iter().map(|c| c.id).collect())
}

fn autosubmit(cfg: &gerrit::Config) -> Result<bool> {
   let mut submittable_changes: HashSet<String> = Default::default();

   for change in list_submittable(cfg)? {
      if !is_submittable(cfg, &change)? {
         continue;
      }

      submittable_changes.insert(change.id.clone());
   }

   let mut chains: BTreeMap<usize, String> = Default::default();
   for change_id in &submittable_changes {
      let ancestors = submitted_with(cfg, change_id)?;
      if ancestors.is_subset(&submittable_changes) {
         chains.insert(
            if ancestors.is_empty() {
               1
            } else {
               ancestors.len()
            },
            change_id.clone(),
         );
      }
   }

   // BTreeMap::last_key_value gives us the value associated with the
   // largest key, i.e. with the longest submittable chain of changes.
   if let Some((count, change_id)) = chains.last_key_value() {
      println!(
         "submitting change {} with chain length {}",
         change_id, count
      );

      gerrit::submit(cfg, change_id).context("while submitting")?;

      Ok(true)
   } else {
      println!("nothing ready for autosubmit, waiting ...");
      Ok(false)
   }
}

fn main() -> Result<()> {
   let cfg = gerrit::Config::from_env()?;

   loop {
      if !autosubmit(&cfg)? {
         thread::sleep(time::Duration::from_secs(cfg.interval));
      }
   }
}
