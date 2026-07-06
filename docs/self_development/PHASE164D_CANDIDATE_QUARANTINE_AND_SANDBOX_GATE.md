# PHASE164D Candidate Quarantine and Sandbox Gate

Purpose:
Create the gate between Owner Candidate Inbox and future atom promotion.

Flow:
candidate inbox -> quarantine gate -> sandbox review -> validation proof -> promote/reject

This phase does not:
- promote candidates;
- mutate accepted core;
- mutate route lock;
- execute Codex;
- run candidate code.

It only creates the controlled quarantine/sandbox boundary.
