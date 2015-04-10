
/******************************************************************************
MySql file to create the basic DFA workflow schema.  This file should only
be run for initial create as it erases (drops) the dfa database before
re-creating it again.

Note: In MySql, the length specified for the int is a display width for
a result set, and has no effect on the range of the datatype.
******************************************************************************/

drop database dfa;
create database dfa;
use dfa;

/*********************************************************************
These lookup tables are frequently accessed but infrequently modified.
Therefore, liberally create indices for them.
*********************************************************************/

CREATE TABLE LKUP_CONSTRAINT
	(
	CONSTRAINT_ID   INT NOT NULL PRIMARY KEY,
	DESCRIPTION_TX    VARCHAR (128) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	DEVELOPER_DESC_TX VARCHAR (128) NULL
	)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_APPLICATION (
	APPLICATION_ID INT NOT NULL PRIMARY KEY,
	APPLICATION_NM VARCHAR(21) NOT NULL,
	APPLICATION_DESC VARCHAR(128) NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX (APPLICATION_NM)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_CONSTRAINT_APP (
	APPLICATION_ID INT NOT NULL,
	CONSTRAINT_ID  INT NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID) REFERENCES LKUP_APPLICATION (APPLICATION_ID),
	CONSTRAINT FOREIGN KEY (CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT (CONSTRAINT_ID)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_CONSTRAINT_APP_ROLE
	(
	APPLICATION_ID INT NOT NULL,
	ROLE_NM         VARCHAR (16) NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	IS_SHOW            BIT DEFAULT 1 NOT NULL,
	ALLOW_UPDATE    BIT DEFAULT 1 NOT NULL,
	IS_RESPONSIBLE     BIT DEFAULT 0 NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,ROLE_NM,CONSTRAINT_ID),
	CONSTRAINT MUST_ALLOW_ONE CHECK  (IS_SHOW <> 0 OR ALLOW_UPDATE <> 0 OR IS_RESPONSIBLE <> 0),
	CONSTRAINT FK_LKUP_CONSTRAINT_APP FOREIGN KEY (APPLICATION_ID,CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP (APPLICATION_ID,CONSTRAINT_ID),
	INDEX (IS_SHOW),
	INDEX (ALLOW_UPDATE),
	INDEX (IS_RESPONSIBLE)
	)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_ENTITY (
	ENTITY_ID INT NOT NULL PRIMARY KEY,
	ENTITY_TX VARCHAR(60) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP	
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_FIELD_TYP (
	FIELD_TYP_ID SMALLINT NOT NULL PRIMARY KEY,
	FIELD_TYP_TX VARCHAR(60) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP	
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_FIELD (
	FIELD_ID INT NOT NULL PRIMARY KEY,
	FIELD_TYP_ID SMALLINT NOT NULL REFERENCES LKUP_FIELD_TYP (FIELD_TYP_ID),
	ENTITY_ID INT NOT NULL REFERENCES LKUP_ENTITY (ENTITY_ID),
	FIELD_TX VARCHAR(60) NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP	
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

CREATE TABLE LKUP_CONSTRAINT_APP_FIELD (
	APPLICATION_ID INT NOT NULL,
	FIELD_ID       INT NOT NULL REFERENCES LKUP_FIELD (FIELD_ID),
	CONSTRAINT_ID  INT NOT NULL,
	NULL_VALID BIT DEFAULT 0, 
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID),
	CONSTRAINT FOREIGN KEY (APPLICATION_ID,CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP (APPLICATION_ID,CONSTRAINT_ID),
	INDEX (NULL_VALID)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

-- No overlaps, trigger enforced.
-- for bit fields, make both SMALLEST_VALUE and LARGEST_VALUE to be 1 or 0.
CREATE TABLE LKUP_CONSTRAINT_FIELD_INT_RANGE (
	APPLICATION_ID INT NOT NULL,
	FIELD_ID INT NOT NULL,
	CONSTRAINT_ID INT NOT NULL,
	SMALLEST_VALUE BIGINT NOT NULL DEFAULT -9223372036854775808,
	LARGEST_VALUE BIGINT NOT NULL DEFAULT 9223372036854775807,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (APPLICATION_ID,FIELD_ID,CONSTRAINT_ID, SMALLEST_VALUE),
	CONSTRAINT FOREIGN KEY FK_LKUP_CONSTRAINT_APP_FIELD (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID) REFERENCES LKUP_CONSTRAINT_APP_FIELD (APPLICATION_ID, FIELD_ID, CONSTRAINT_ID),
	CONSTRAINT CHECK (SMALLEST_VALUE <= LARGEST_VALUE),
	INDEX (LARGEST_VALUE)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;
 
CREATE TABLE LKUP_EVENT (
	EVENT_TYP            INT NOT NULL,
	SORT_ORDER           INT DEFAULT 0 NOT NULL,
	MAKE_CURRENT         BIT DEFAULT 1 NOT NULL,
	EVENT_NM             VARCHAR (20) NOT NULL,
	EVENT_TX             VARCHAR (60) NOT NULL,
	ATTENTION            BIT DEFAULT 0 NOT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (EVENT_TYP),
	INDEX (MAKE_CURRENT),
	INDEX (ATTENTION)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

-- Insert this one row because it is used as a default value.
insert into LKUP_EVENT (EVENT_TYP,EVENT_NM,EVENT_TX,MOD_BY) VALUES (1,'Start','Start Action','DFA-Create');
COMMIT;

create table LKUP_STATE (
	STATE_TYP INT(5) NOT NULL,
	STATE_NM VARCHAR(32) NOT NULL,
	STATE_TX VARCHAR(128) NOT NULL,
	ACTIVE BIT(1) NOT NULL DEFAULT 1,
	PSEUDO BIT(1) NOT NULL DEFAULT 0,
	FLAGGED BIT (1) NOT NULL DEFAULT 0,
	EXPECTED_NEXT_EVENT INT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (STATE_TYP),
	INDEX (ACTIVE),
	INDEX (FLAGGED)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

create table LKUP_EVENT_STATE_TRANS (
	STATE_TYP INT NOT NULL REFERENCES LKUP_STATE (STATE_TYP),
	EVENT_TYP INT NOT NULL REFERENCES LKUP_EVENT (EVENT_TYP),
	NEXT_EVENT_TYP INT NOT NULL REFERENCES LKUP_STATE (STATE_TYP),
	EVENT_TX VARCHAR (60) NULL, -- Overrides LKUP_EVENT.EVENT_TX if defined.
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,	
	PRIMARY KEY (STATE_TYP,EVENT_TYP),
	INDEX (NEXT_EVENT_TYP)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

alter table LKUP_STATE ADD CONSTRAINT FOREIGN KEY (STATE_TYP,EXPECTED_NEXT_EVENT) 
	REFERENCES LKUP_EVENT_STATE_TRANS (STATE_TYP,EVENT_TYP);

-- Must insert this to make default value for 
-- START_EVENT_TYP valid
create table LKUP_ACTION_TYP (
	ACTION_TYP INT NOT NULL PRIMARY KEY,
	ACTION_NM VARCHAR(32) NOT NULL,
	ACTION_TX VARCHAR(128) NOT NULL,
	START_STATE_TYP INT NOT NULL REFERENCES LKUP_STATE (STATE_TYP),
	START_EVENT_TYP INT NOT NULL DEFAULT 1 REFERENCES LKUP_EVENT (EVENT_TYP),
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

create table DFA_ACTION (
	DFA_ACTION_ID BIGINT NOT NULL PRIMARY KEY,
	ACTION_TYP INT NOT NULL,
	COMMENT_TX MEDIUMTEXT NULL,
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT FK_ACTION_TYP FOREIGN KEY (ACTION_TYP) REFERENCES LKUP_ACTION_TYP (ACTION_TYP)
)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;

create table DFA_ACTION_STATE (
	DFA_ACTION_ID BIGINT NOT NULL,
	DFA_STATE_ID INT NOT NULL,
	IS_CURRENT BIT DEFAULT 1,
	STATE_TYP INT NOT NULL,
	EVENT_TYP INT NOT NULL,
	PARENT_STATE_ID INT NOT NULL,
	UNDO_STATE_ID INT NULL,
	COMMENT_TX MEDIUMTEXT NULL, 
	MOD_BY VARCHAR(32) NOT NULL,
	MOD_DT TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	PRIMARY KEY (DFA_ACTION_ID,DFA_STATE_ID),
	CONSTRAINT FK_DFA_ACTION FOREIGN KEY (DFA_ACTION_ID) REFERENCES DFA_ACTION (DFA_ACTION_ID),
	CONSTRAINT FK_LKUP_STATE FOREIGN KEY (STATE_TYP) REFERENCES LKUP_STATE (STATE_TYP),
	CONSTRAINT FK_LKUP_EVENT FOREIGN KEY (EVENT_TYP) REFERENCES LKUP_EVENT (EVENT_TYP),	
	CONSTRAINT FK_PARENT_STATE FOREIGN KEY (DFA_ACTION_ID,PARENT_STATE_ID) references DFA_ACTION_STATE (DFA_ACTION_ID,DFA_STATE_ID),
	CONSTRAINT FK_UNDO_STATE FOREIGN KEY (DFA_ACTION_ID,UNDO_STATE_ID) references DFA_ACTION_STATE (DFA_ACTION_ID,DFA_STATE_ID),
	CONSTRAINT PARENT_NOT_FUTURE CHECK (PARENT_STATE_ID <= DFA_STATE_ID),
	CONSTRAINT UNDO_IS_PAST CHECK (UNDO_STATE_ID IS NULL OR UNDO_STATE_ID < DFA_STATE_ID),
	INDEX (IS_CURRENT)
	)
COLLATE='utf8_general_ci'
ENGINE=InnoDB;
