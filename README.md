# To do For DFA Workflow Project #
## Current Status: Waiting for HP (my employer) to approve open source project. ##
## To do list ##

1. Migrate to PostgreSQL database.  This is primarily to take advantage of their JSONB (jason as binary) support.
2. Implement the following features (some merely need a unit test to be done):
	-  Parallel Sub-state workflows
	-  Conditional state processing
	-  Undoable Operations
	-  Passive Events
	-  Compute (show) workflow (both from start and remaining for a given in-progress workflow).
	-  Concurrent events (light weight alternative for parallel sub-state workflows when exactly 1 event completes a sub-operation).
	-  Global transitions - Event -> state transitions that automatically apply to any active state (`LKUP_STATE.ACTIVE = 1`).
3. 
4. Create state REST micro service
	- Allow storage of client entities using JSON.  Client must also store key (or should there be an option to auto-generate it, or skip it?)
	- Figure out a way to map JSON attributes into `ENTITY` and `FIELD` so they may be processed by the constraint framework.
	- Figure out best way for client to inform micro service of user's roles.