use std::{
   collections::{
      HashMap,
      HashSet,
   },
   thread,
   time,
};

use anyhow::{
   Context as _,
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

   for change in changes {
      let Some(revision) = change.revisions.into_keys().next() else {
         eprintln!(
            "WARNING: skipping change {} (no current revision)",
            change.id
         );
         continue;
      };
      out.push(SubmittableChange {
         id: change.id,
         revision,
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

   response
      .get("submit")
      .map_or_else(|| Ok(false), |action| Ok(action.enabled))
}

fn submitted_with(cfg: &gerrit::Config, change_id: &str) -> Result<HashSet<String>> {
   let response: Vec<gerrit::ChangeInfo> =
      gerrit::get(cfg, &format!("/changes/{change_id}/submitted_together"))
         .context("failed to fetch related change list")?;

   Ok(response.into_iter().map(|c| c.id).collect())
}

fn autosubmit(cfg: &gerrit::Config) -> Result<bool> {
   let mut submittable_changes: HashSet<String> = HashSet::default();

   for change in list_submittable(cfg)? {
      if !is_submittable(cfg, &change)? {
         continue;
      }

      submittable_changes.insert(change.id.clone());
   }

   let mut best_len = 0_usize;
   let mut best_id: Option<String> = None;
   for change_id in &submittable_changes {
      let ancestors = submitted_with(cfg, change_id)?;
      if ancestors.is_subset(&submittable_changes) {
         let len = if ancestors.is_empty() {
            1
         } else {
            ancestors.len()
         };
         if len > best_len {
            best_len = len;
            best_id = Some(change_id.clone());
         }
      }
   }

   if let Some(change_id) = best_id {
      println!("submitting change {change_id} with chain length {best_len}");

      gerrit::submit(cfg, &change_id).context("while submitting")?;

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
