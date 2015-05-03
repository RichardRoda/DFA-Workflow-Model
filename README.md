# To do For DFA Workflow Project #
## Current Status: Waiting for HP (my employer) to approve open source project. ##
## To do list ##

1. Migrate to PostgreSQL database.  This is primarily to take advantage of their JSONB (jason as binary) support.
1. Implement the following features (some merely need a unit test to be done):
	-  Parallel Sub-state workflows
	-  Conditional state processing
	-  Undoable Operations
	-  Passive Events
	-  Compute (show) workflow (both from start and remaining for a given in-progress workflow).
	-  Concurrent events (light weight alternative for parallel sub-state workflows when exactly 1 event completes a sub-operation).
	-  Global transitions - Event -> state transitions that automatically apply to any active state (`LKUP_STATE.ACTIVE = 1`).
1. Create RESTful micro service
	- Allow storage of client entities using JSON.  Client must either store key or request one be auto-generated.  Auto generated keys are always `BIGINT UNSIGNED`.
	- Figure out a way to map JSON attributes into `ENTITY` and `FIELD` so they may be processed by the constraint framework.
	- Figure out best way for client to inform micro service of user's roles.  One possibility other than sending all of them each time is to send an MD5 of the roles, and then only send them (with the MD5) if the service responds that it does not know what the MD5 represents.  MD5 -> Roles could be stored using a TTL (time to live) method where entries where the TTL is expired are pruned.