-- #########################################################################
-- # SQL source for the perm PostgreSQL database
-- # 
-- # This database design and code was donated by 
-- #
-- #     Stiftung 3FO, CH-4600 Olten and
-- #     Forem AG, CH-4600 Olten
-- #
-- # Code written by Roman Plessl <roman.plessl@prunux.ch>
-- #
-- #     Perm is a permission and access management system with RDMS.
-- #     Copyright (C) 2015-2019, Stiftung 3FO, CH-4600 Olten
-- #     Copyright (C) 2015-2019, Forem AG, CH-4600 Olten
-- #     Copyright (C) 2015-2019, Roman Plessl (prunux.ch)
-- # 
-- #     This program is free software: you can redistribute it and/or modify
-- #     it under the terms of the GNU General Public License as published by
-- #     the Free Software Foundation, either version 3 of the License, or
-- #     (at your option) any later version.
-- # 
-- #     This program is distributed in the hope that it will be useful,
-- #     but WITHOUT ANY WARRANTY; without even the implied warranty of
-- #     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- #     GNU General Public License for more details.
-- # 
-- #     You should have received a copy of the GNU General Public License
-- #     along with this program.  If not, see <http://www.gnu.org/licenses/>.
-- #
-- #########################################################################

-- #########################################################################
-- Setup the user groups and users
-- #########################################################################

CREATE GROUP perm;
CREATE GROUP perm_user;
CREATE GROUP perm_admin;

CREATE USER perm_master IN GROUP perm_admin, perm_user, perm;
ALTER  USER perm_master WITH PASSWORD '1234abcdqwer';
-- #########################################################################
-- Setup the database
-- ##########################################################################

DROP DATABASE IF EXISTS perm;

CREATE DATABASE perm
    TEMPLATE = template0
    ENCODING = 'UTF8';

COMMENT ON DATABASE perm IS 'perm application';

GRANT ALL ON DATABASE perm TO perm_master;

ALTER DATABASE perm OWNER TO perm_master;;

\connect perm perm_master;

-- ############################################################################
-- Grants
-- ############################################################################

REVOKE ALL   ON DATABASE perm  FROM PUBLIC;

GRANT CONNECT ON DATABASE perm TO perm_user;
GRANT CONNECT ON DATABASE perm TO perm_admin;

-- ############################################################################
-- Set PostgreSQL DB defaults and group functions
-- ############################################################################

-- let's loose our superior powers
SET SESSION AUTHORIZATION 'perm_master';

-- let's set postgres specific parameter
SET DateStyle TO 'European';
SET search_path = public, pg_catalog;

DROP FUNCTION IF EXISTS ingroup(name);
CREATE OR REPLACE FUNCTION ingroup(name) RETURNS BOOLEAN AS '
    SELECT CASE WHEN (SELECT TRUE
      FROM pg_user, pg_group
     WHERE groname = $1
       AND usename = CURRENT_USER
       AND usesysid = ANY (grolist)) THEN TRUE
      ELSE FALSE
       END;
' LANGUAGE 'sql';

-- #########################################################################
-- Base Functions For Gedafe
-- #########################################################################

-- ######################
-- Field Meta Information
-- ######################

-- this table lists all fields which have special properties
DROP TABLE IF EXISTS meta_fields;
CREATE TABLE meta_fields (
    meta_fields_table       NAME    NOT NULL,   -- Table Name
    meta_fields_field       NAME    NOT NULL,   -- Field Name
    meta_fields_attribute   TEXT    NOT NULL,   -- Attribute
    meta_fields_value       TEXT,               -- Value
    UNIQUE(meta_fields_table,meta_fields_field,meta_fields_attribute)
);

GRANT SELECT ON meta_fields TO GROUP perm_user;

-- ######################
-- Table Meta Information
-- ######################

-- this table lists all tables which have special properties
DROP TABLE IF EXISTS meta_tables;
CREATE TABLE meta_tables (
    meta_tables_table       NAME NOT NULL,  -- Table Name
    meta_tables_attribute   TEXT NOT NULL,  -- Attribute
    meta_tables_value       TEXT,           -- Value
    UNIQUE(meta_tables_table,meta_tables_attribute)
);

GRANT SELECT ON meta_tables TO GROUP perm_user;

-- #############
-- Error logging
-- #############

DROP FUNCTION IF EXISTS elog(text);
CREATE OR REPLACE FUNCTION elog(text) RETURNS BOOLEAN AS
    'BEGIN RAISE EXCEPTION ''%'', $1 ; END;' LANGUAGE 'plpgsql';

DROP TABLE IF EXISTS elog;
CREATE TABLE elog ( elog bool );
INSERT INTO elog VALUES (true);

INSERT INTO meta_tables VALUES ('elog', 'hide', '1');

-- ##########################################################################
-- Config Table - Config Fields for perm Databse
-- ##########################################################################

DROP TABLE IF EXISTS perm_config;
DROP SEQUENCE IF EXISTS perm_perm_config_id_seq;
CREATE TABLE perm_config (
    perm_config_id    SERIAL NOT NULL PRIMARY KEY,
    perm_config_hid   NAME   NOT NULL UNIQUE,
    perm_config_value TEXT   NOT NULL,
    perm_config_note  TEXT
) WITH OIDS;

GRANT SELECT,UPDATE,INSERT ON perm_config TO GROUP perm_admin;
GRANT SELECT               ON perm_config TO GROUP perm_user;

COMMENT ON TABLE  perm_config IS 'Z perm Konfiguration';
COMMENT ON COLUMN perm_config.perm_config_id    IS 'ID';
COMMENT ON COLUMN perm_config.perm_config_hid   IS 'Key';
COMMENT ON COLUMN perm_config.perm_config_value IS 'Value';
COMMENT ON COLUMN perm_config.perm_config_note  IS 'Note';

INSERT INTO meta_fields
       VALUES ('perm_config','perm_config_note', 'widget','area');

CREATE OR REPLACE FUNCTION get_perm_config(NAME) RETURNS TEXT AS $$
    SELECT perm_config_value
    FROM   perm_config
    WHERE  perm_config_hid = $1;
$$ LANGUAGE 'sql' IMMUTABLE;

INSERT INTO meta_tables VALUES ('perm_config', 'hide', '1');

-- ##########################################################################
-- Pers table - Every person is listed in this table
-- ##########################################################################

DROP TABLE IF EXISTS pers;
DROP SEQUENCE IF EXISTS pers_pers_id_seq;
CREATE TABLE pers (
   pers_id           SERIAL  NOT NULL PRIMARY KEY,               -- Unique ID
   pers_hid          NAME    NOT NULL UNIQUE,                    -- Human Readable Unique ID
   pers_first        TEXT    NOT NULL CHECK (pers_first != ''),  -- First Name of Person
   pers_last         TEXT    NOT NULL CHECK (pers_last != ''),   -- Last Name of Person
   pers_start        DATE    NOT NULL DEFAULT CURRENT_DATE,      -- Is the Worker active ...
   pers_end          DATE             CHECK (pers_end is NULL or pers_end > pers_start), -- or inactive
   pers_desc         TEXT             CHECK (pers_desc != ''),   -- Explanation
   pers_external     BOOLEAN NOT NULL DEFAULT false,             -- Does this pers is an external co-worker
   pers_mod_date     DATE,                                       -- last change on
   pers_mod_user     NAME                                        -- ... by whom
) WITH OIDS;

GRANT SELECT                      ON pers_pers_id_seq TO GROUP perm_user;
GRANT SELECT                      ON pers             TO GROUP perm_user;
GRANT SELECT,UPDATE               ON pers_pers_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON pers             TO GROUP perm_admin;


INSERT INTO meta_fields
    VALUES ('pers', 'pers_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('pers', 'pers_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('pers', 'pers_mod_user','widget','readonly');

COMMENT ON TABLE  pers               IS 'M Mitarbeiter';
COMMENT ON COLUMN pers.pers_id       IS 'ID';
COMMENT ON COLUMN pers.pers_hid      IS 'Benutzername';
COMMENT ON COLUMN pers.pers_first    IS 'Vorname';
COMMENT ON COLUMN pers.pers_last     IS 'Nachname';
COMMENT ON COLUMN pers.pers_desc     IS 'Bemerkung';
COMMENT ON COLUMN pers.pers_start    IS 'Start';
COMMENT ON COLUMN pers.pers_end      IS 'End (Ex Mitarbeiter)';
COMMENT ON COLUMN pers.pers_external IS 'Extern';
COMMENT ON COLUMN pers.pers_mod_date IS 'Veraendert am';
COMMENT ON COLUMN pers.pers_mod_user IS 'Veraendert von';

-- let authorization figure the current user
CREATE OR REPLACE VIEW current_pers AS
    SELECT * FROM pers WHERE pers_hid = CURRENT_USER;

INSERT INTO meta_tables
    VALUES ('current_pers', 'hide', '1');

GRANT SELECT ON current_pers TO GROUP perm_user;

-- shortcut function
CREATE OR REPLACE FUNCTION pers_hid2id(NAME) returns int4
    AS 'SELECT pers_id FROM pers WHERE pers_hid = $1 ' STABLE LANGUAGE 'sql';

-- Combo: ID, HID -- Last Frist Name
CREATE OR REPLACE VIEW pers_combo AS
    SELECT pers_id AS id,
           (pers_hid || ' -- ' || pers_last  || ', ' || pers_first) AS text
    FROM   pers
    ORDER BY pers_hid, pers_last, pers_first;

GRANT SELECT ON pers_combo TO GROUP perm_user;

-- ##########################################################################
-- Org table - Every organisation is listed in this table
-- ##########################################################################

DROP TABLE IF EXISTS org;
DROP SEQUENCE IF EXISTS org_org_id_seq;
CREATE TABLE org (
   org_id            SERIAL NOT NULL  PRIMARY KEY,             -- Unique ID
   org_hid           NAME   NOT NULL  UNIQUE,                  -- Human Readable Unique ID
   org_name          TEXT   NOT NULL  CHECK (org_name != ''),  -- Name of Organisation
   org_pers          INT4   NOT NULL  REFERENCES pers,         -- owner
   org_start         DATE   NOT NULL  DEFAULT CURRENT_DATE,    -- Is the Organisation active
   org_end           DATE             CHECK (org_end is NULL or org_end > org_start), -- or inactive
   org_desc          TEXT             CHECK (org_desc != ''),  -- Explanation
   org_external      BOOLEAN NOT NULL DEFAULT false,           -- Does this organisation is an external organisation
   org_mod_date      DATE,                                     -- last change
   org_mod_user      NAME                                      -- by whom
) WITH OIDS;

GRANT SELECT                      ON org_org_id_seq TO GROUP perm_user;
GRANT SELECT                      ON org            TO GROUP perm_user;
GRANT SELECT,UPDATE               ON org_org_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON org            TO GROUP perm_admin;


INSERT INTO meta_fields
    VALUES ('org', 'org_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('org', 'org_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('org', 'org_mod_user','widget','readonly');

COMMENT ON TABLE  org              IS 'N Organisationen';
COMMENT ON COLUMN org.org_id       IS 'ID';
COMMENT ON COLUMN org.org_hid      IS 'Abkuerzung';
COMMENT ON COLUMN org.org_name     IS 'Name';
COMMENT ON COLUMN org.org_pers     IS 'Verantwortlich';
COMMENT ON COLUMN org.org_desc     IS 'Bemerkung';
COMMENT ON COLUMN org.org_start    IS 'Start';
COMMENT ON COLUMN org.org_end      IS 'End (Ex Organisation)';
COMMENT ON COLUMN org.org_external IS 'Extern';
COMMENT ON COLUMN org.org_mod_date IS 'Veraendert am';
COMMENT ON COLUMN org.org_mod_user IS 'Veraendert von';

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION org_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.org_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.org_mod_date := CURRENT_DATE;
        NEW.org_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.org_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER org_trigger BEFORE INSERT OR UPDATE OR DELETE ON org FOR EACH ROW
    EXECUTE PROCEDURE org_checker();

-- shortcut function
CREATE OR REPLACE FUNCTION org_hid2id(NAME) returns int4
    AS 'SELECT org_id FROM org WHERE org_hid = $1 ' STABLE LANGUAGE 'sql';

-- Combo: ID, HID -- Name
CREATE OR REPLACE VIEW org_combo AS
    SELECT org_id AS id,
           (org_hid || ' -- ' || org_name) AS text
    FROM   org
    ORDER BY org_hid, org_name;

GRANT SELECT ON org_combo TO GROUP perm_user;

-- List view: use hid instead of id for pers
CREATE OR REPLACE VIEW org_list AS
    SELECT  org_id,
            org_hid,
            org_name,
            pers_hid AS org_pers,
            org_start,
            org_end,
            org_desc,
            org_external,
            org_mod_date,
            org_mod_user
    FROM    org, pers
    WHERE   org_pers = pers_id;

GRANT SELECT ON org_list TO GROUP perm_user;

-- ##########################################################################
-- function table - Every function is listed in this table
-- ##########################################################################

DROP TABLE IF EXISTS function;
DROP SEQUENCE IF EXISTS function_function_id_seq;
CREATE TABLE function (
   function_id         SERIAL NOT NULL  PRIMARY KEY,             -- Unique ID
   function_hid        NAME   NOT NULL  UNIQUE,                  -- Human Readable Unique ID
   function_name       TEXT   NOT NULL  CHECK (function_name != ''),  -- Name of functionanisation
   function_pers       INT4   NOT NULL  REFERENCES pers,         -- owner
   function_start      DATE   NOT NULL  DEFAULT CURRENT_DATE,    -- Is the functionanisation active
   function_end        DATE             CHECK (function_end is NULL or function_end > function_start), -- or inactive
   function_desc       TEXT             CHECK (function_desc != ''),  -- Explanation
   function_mod_date   DATE,                                     -- last change
   function_mod_user   NAME                                      -- by whom
) WITH OIDS;

GRANT SELECT                      ON function_function_id_seq TO GROUP perm_user;
GRANT SELECT                      ON function                 TO GROUP perm_user;
GRANT SELECT,UPDATE               ON function_function_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON function                 TO GROUP perm_admin;


INSERT INTO meta_fields
    VALUES ('function', 'function_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('function', 'function_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('function', 'function_mod_user','widget','readonly');

COMMENT ON TABLE  function                   IS 'O Funktionen';
COMMENT ON COLUMN function.function_id       IS 'ID';
COMMENT ON COLUMN function.function_hid      IS 'Abkuerzung';
COMMENT ON COLUMN function.function_name     IS 'Name';
COMMENT ON COLUMN function.function_pers     IS 'Verantwortlich';
COMMENT ON COLUMN function.function_desc     IS 'Bemerkung';
COMMENT ON COLUMN function.function_start    IS 'Start';
COMMENT ON COLUMN function.function_end      IS 'End (Ex Funktion)';
COMMENT ON COLUMN function.function_mod_date IS 'Veraendert am';
COMMENT ON COLUMN function.function_mod_user IS 'Veraendert von';

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION function_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.function_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.function_mod_date := CURRENT_DATE;
        NEW.function_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.function_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER function_trigger BEFORE INSERT OR UPDATE OR DELETE ON function FOR EACH ROW
    EXECUTE PROCEDURE function_checker();

-- shortcut function
CREATE OR REPLACE FUNCTION function_hid2id(NAME) returns int4
    AS 'SELECT function_id FROM function WHERE function_hid = $1 ' STABLE LANGUAGE 'sql';

-- Combo: ID, HID -- Name
CREATE OR REPLACE VIEW function_combo AS
    SELECT function_id AS id,
           (function_hid || ' -- ' || function_name) AS text
    FROM   function
    ORDER BY function_hid, function_name;

GRANT SELECT ON function_combo TO GROUP perm_user;

-- List view: use hid instead of id for pers
CREATE OR REPLACE VIEW function_list AS
    SELECT  function_id,
            function_hid,
            function_name,
            pers_hid AS function_pers,
            function_start,
            function_end,
            function_desc,
            function_mod_date,
            function_mod_user
    FROM    function, pers
    WHERE   function_pers = pers_id;

GRANT SELECT ON function_list TO GROUP perm_user;

-- ##########################################################################
-- pers org table - Every organisation membership is listed in this table
-- ##########################################################################

DROP TABLE IF EXISTS persorg;
DROP SEQUENCE IF EXISTS persorg_persorg_id_seq;
CREATE TABLE persorg (
   persorg_id        SERIAL NOT NULL  PRIMARY KEY,            -- Unique ID
   persorg_pers      INT4   NOT NULL  REFERENCES pers,        -- worker
   persorg_org       INT4   NOT NULL  REFERENCES org,         -- organisation
   persorg_function  INT4   NOT NULL  REFERENCES function,    -- function
   persorg_start     DATE   NOT NULL  DEFAULT CURRENT_DATE,   -- Is the FI active
   persorg_end       DATE             CHECK (persorg_end is NULL or persorg_end > persorg_start), -- or inactive
   persorg_desc      TEXT             CHECK (persorg_desc != ''), -- Explanation
   persorg_mandate   BOOLEAN NOT NULL DEFAULT false,          -- Does this person is a FI on mandate basis?
   persorg_mod_date  DATE,                                    -- last change on
   persorg_mod_user  NAME                                     -- ... by whom
) WITH OIDS;

GRANT SELECT                      ON persorg_persorg_id_seq TO GROUP perm_user;
GRANT SELECT                      ON persorg                TO GROUP perm_user;
GRANT SELECT,UPDATE               ON persorg_persorg_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON persorg                TO GROUP perm_admin;

INSERT INTO meta_fields
    VALUES ('persorg', 'persorg_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('persorg', 'persorg_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('persorg', 'persorg_mod_user','widget','readonly');

COMMENT ON TABLE  persorg                  IS 'P Funktionsinhaber';
COMMENT ON COLUMN persorg.persorg_id       IS 'ID';
COMMENT ON COLUMN persorg.persorg_pers     IS 'Mitarbeiter';
COMMENT ON COLUMN persorg.persorg_org      IS 'Organisation';
COMMENT ON COLUMN persorg.persorg_function IS 'Funktion';
COMMENT ON COLUMN persorg.persorg_start    IS 'Start';
COMMENT ON COLUMN persorg.persorg_end      IS 'End (Ex FI)';
COMMENT ON COLUMN persorg.persorg_mandate  IS 'Mandat';
COMMENT ON COLUMN persorg.persorg_desc     IS 'Bemerkung';
COMMENT ON COLUMN persorg.persorg_mod_date IS 'Veraendert am';
COMMENT ON COLUMN persorg.persorg_mod_user IS 'Veraendert von';

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION persorg_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.persorg_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.persorg_mod_date := CURRENT_DATE;
        NEW.persorg_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.persorg_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER persorg_trigger BEFORE INSERT OR UPDATE OR DELETE ON persorg FOR EACH ROW
    EXECUTE PROCEDURE persorg_checker();

-- Combo: ID, Org (Orgname) -- Username (Lastname Firstname)
CREATE OR REPLACE VIEW persorg_combo AS
    SELECT persorg_id AS id,
           (org_hid || '-- ' || function_hid || '-- ' || pers_hid || ' (' || pers_last  || ', ' || pers_first || ') ') AS text
    FROM   persorg, org, pers, function
    WHERE  persorg_pers     = pers_id
      AND  persorg_org      = org_id
      AND  persorg_function = function_id
  ORDER BY pers_hid;

GRANT SELECT ON persorg_combo TO GROUP perm_user;

-- List view: use hid instead of id for pers, org and function
CREATE OR REPLACE VIEW persorg_list AS
    SELECT  persorg_id,
            org_hid      AS persorg_org,
            function_hid AS persorg_function,
            pers_hid     AS persorg_pers,
            persorg_start,
            persorg_end,
            persorg_desc,
            persorg_mandate,
            persorg_mod_date,
            persorg_mod_user
    FROM    persorg, org, pers, function
    WHERE   persorg_org      = org_id
      AND   persorg_pers     = pers_id
      AND   persorg_function = function_id;

GRANT SELECT ON persorg_list TO GROUP perm_user;

-- ##########################################################################
-- Type table - Every type is listed in this table
-- ##########################################################################

DROP TABLE IF EXISTS type;
DROP SEQUENCE IF EXISTS type_type_id_seq;
CREATE TABLE type (
    type_id            SERIAL NOT NULL PRIMARY KEY,              -- Unique ID
    type_hid           NAME   NOT NULL UNIQUE,                   -- Human Readable Unique ID
    type_name          TEXT   NOT NULL CHECK (type_name != ''),  -- Name of Type
    type_pers          INT4   NOT NULL REFERENCES pers,          -- owner
    type_start         DATE   NOT NULL DEFAULT CURRENT_DATE,     -- Is the Type active
    type_end           DATE            CHECK (type_end is NULL or type_end > type_start),
    type_desc          TEXT            CHECK (type_desc != ''),  -- Explanation
    type_mod_date      DATE,                                     -- last change on
    type_mod_user      NAME                                      -- ... by whom
) WITH OIDS;

GRANT SELECT                      ON type_type_id_seq TO GROUP perm_user;
GRANT SELECT                      ON type             TO GROUP perm_user;
GRANT SELECT,UPDATE               ON type_type_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON type             TO GROUP perm_admin;

INSERT INTO meta_fields
    VALUES ('type', 'type_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('type', 'type_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('type', 'type_mod_user','widget','readonly');

COMMENT ON TABLE  type               IS 'D Typen';
COMMENT ON COLUMN type.type_id       IS 'ID';
COMMENT ON COLUMN type.type_hid      IS 'Abkuerzung';
COMMENT ON COLUMN type.type_name     IS 'Name';
COMMENT ON COLUMN type.type_pers     IS 'Verantwortlich';
COMMENT ON COLUMN type.type_desc     IS 'Bemerkung';
COMMENT ON COLUMN type.type_start    IS 'Start';
COMMENT ON COLUMN type.type_end      IS 'End (Ex Type)';
COMMENT ON COLUMN type.type_mod_date IS 'Veraendert am';
COMMENT ON COLUMN type.type_mod_user IS 'Veraendert von';

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION type_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.type_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.type_mod_date := CURRENT_DATE;
        NEW.type_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.type_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER type_trigger BEFORE INSERT OR UPDATE OR DELETE ON type FOR EACH ROW
    EXECUTE PROCEDURE type_checker();

-- shortcut function
CREATE OR REPLACE FUNCTION type_hid2id(NAME) returns int4
    AS 'SELECT type_id FROM type WHERE type_hid = $1 ' STABLE LANGUAGE 'sql';

-- Combo: HID -- Name
CREATE OR REPLACE VIEW type_combo AS
    SELECT type_id AS id,
           (type_hid || ' -- ' || type_name) AS text
    FROM type
    ORDER BY type_hid, type_name;

GRANT SELECT ON type_combo TO GROUP perm_user;

CREATE OR REPLACE VIEW type_list AS
        SELECT  type_id,
                type_hid,
                type_name,
                pers_hid AS type_pers,
                type_start,
                type_end,
                type_desc,
                CASE
                    WHEN current_date < type_start
                        THEN false
                    WHEN current_date > type_end
                        THEN false
                    ELSE true
                END AS active
        FROM    type, pers
        WHERE   type_pers = pers_id;

GRANT SELECT ON type_list TO GROUP perm_user;

COMMENT ON COLUMN type_list.active IS 'Aktiv';


-- ########################################################################################
-- category, subcategory and element tables - Every thing classification is listed in these tables
-- #########################################################################################

DROP TABLE IF EXISTS category;
DROP SEQUENCE IF EXISTS category_category_id_seq;
CREATE TABLE category (
    category_id       SERIAL NOT NULL PRIMARY KEY,                  -- Unique ID
    category_hid      NAME   NOT NULL UNIQUE,                       -- Human Readable Unique ID
    category_name     TEXT   NOT NULL CHECK (category_name != ''),  -- Full Name of categorys
    category_pers     INT4   NOT NULL REFERENCES pers DEFAULT pers_hid2id(current_user), -- category Manager
    category_start    DATE   NOT NULL DEFAULT CURRENT_DATE,         -- category start date
    category_end      DATE            CHECK (category_end IS NULL OR category_end > category_start),
    category_desc     TEXT            CHECK (category_desc != ''),  -- category Description
    category_mod_date DATE,                                         -- last change
    category_mod_user NAME                                          -- by whom
) WITH OIDS;

GRANT SELECT                      ON category_category_id_seq TO GROUP perm_user;
GRANT SELECT                      ON category                 TO GROUP perm_user;
GRANT SELECT,UPDATE               ON category_category_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON category                 TO GROUP perm_admin;

COMMENT ON TABLE  category                   IS 'A Kategorien';
COMMENT ON COLUMN category.category_id       IS 'ID';
COMMENT ON COLUMN category.category_hid      IS 'Abkuerzung';
COMMENT ON COLUMN category.category_name     IS 'Name';
COMMENT ON COLUMN category.category_pers     IS 'Verantwortlich';
COMMENT ON COLUMN category.category_start    IS 'Start';
COMMENT ON COLUMN category.category_end      IS 'End (Ex Kategorie)';
COMMENT ON COLUMN category.category_desc     IS 'Bemerkung';
COMMENT ON COLUMN category.category_mod_date IS 'Veraendert am';
COMMENT ON COLUMN category.category_mod_user IS 'Veraendert von';

INSERT INTO meta_fields
    VALUES ('category','category_desc','widget','area');

INSERT INTO meta_fields
    VALUES ('category', 'category_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('category', 'category_mod_user','widget','readonly');

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION category_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.category_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.category_mod_date := CURRENT_DATE;
        NEW.category_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.category_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER category_trigger BEFORE INSERT OR UPDATE OR DELETE ON category FOR EACH ROW
    EXECUTE PROCEDURE category_checker();

-- shortcut function
CREATE OR REPLACE FUNCTION category_hid2id(NAME) returns int4
    AS 'SELECT category_id FROM category WHERE category_hid = $1 ' STABLE LANGUAGE 'sql';

CREATE OR REPLACE VIEW category_combo AS
        SELECT  category_id AS id,
                CASE
                    WHEN current_date < category_start OR current_date > category_end
                    THEN '~ '
                    ELSE ''
                END ||
                category_hid || ' -- ' || category_name AS text
        FROM category
        ORDER BY category_hid;

GRANT SELECT ON category_combo TO GROUP perm_user;

CREATE OR REPLACE VIEW category_list AS
        SELECT  category_id,
                category_hid,
                category_name,
                pers_hid AS category_pers,
                category_start,
                category_end,
                category_desc,
                CASE
                    WHEN current_date < category_start
                        THEN false
                    WHEN current_date > category_end
                        THEN false
                    ELSE true
                END AS active
        FROM    category, pers
        WHERE   category_pers = pers_id;

GRANT SELECT ON category_list TO GROUP perm_user;

COMMENT ON COLUMN category_list.active IS 'Aktiv';


-- ################
-- # Subcategory #
-- ################

DROP TABLE IF EXISTS subcategory;
DROP SEQUENCE IF EXISTS subcategory_subcategory_id_seq;
CREATE TABLE subcategory (
    subcategory_id        SERIAL NOT NULL PRIMARY KEY,                   -- Unique ID
    subcategory_hid       NAME   NOT NULL UNIQUE,                        -- Human Readable Unique ID
    subcategory_name      TEXT   NOT NULL CHECK (subcategory_name != ''),-- subcategory Name
    subcategory_category  INT4   NOT NULL REFERENCES category,
    subcategory_pers      INT4   NOT NULL REFERENCES pers DEFAULT pers_hid2id(current_user), -- subcategory Manager
    subcategory_start     DATE   NOT NULL DEFAULT CURRENT_DATE,        -- subcategory start date
    subcategory_end       DATE            CHECK (subcategory_end IS NULL OR subcategory_end > subcategory_start), -- subcategory end date
    subcategory_desc      TEXT            CHECK (subcategory_desc != ''),  -- subcategory Description
    subcategory_mod_date  DATE,                                 -- last change
    subcategory_mod_user  NAME                                  -- by whom
) WITH OIDS;

GRANT SELECT                      ON subcategory_subcategory_id_seq TO GROUP perm_user;
GRANT SELECT                      ON subcategory                    TO GROUP perm_user;
GRANT SELECT,UPDATE               ON subcategory_subcategory_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON subcategory                    TO GROUP perm_admin;

COMMENT ON TABLE  subcategory                       IS 'B Subkategorien';
COMMENT ON COLUMN subcategory.subcategory_id        IS 'ID';
COMMENT ON COLUMN subcategory.subcategory_hid       IS 'Abkuerzung';
COMMENT ON COLUMN subcategory.subcategory_name      IS 'Name';
COMMENT ON COLUMN subcategory.subcategory_category  IS 'Kategorie';
COMMENT ON COLUMN subcategory.subcategory_pers      IS 'Verantwortlich';
COMMENT ON COLUMN subcategory.subcategory_start     IS 'Start';
COMMENT ON COLUMN subcategory.subcategory_end       IS 'End (Ex Subkategorie)';
COMMENT ON COLUMN subcategory.subcategory_desc      IS 'Bemerkung';
COMMENT ON COLUMN subcategory.subcategory_mod_date  IS 'Veraendert am';
COMMENT ON COLUMN subcategory.subcategory_mod_user  IS 'Veraendert von';

INSERT INTO meta_fields
    VALUES ('subcategory', 'subcategory_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('subcategory', 'subcategory_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('subcategory', 'subcategory_mod_user','widget','readonly');

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION subcategory_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.subcategory_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.subcategory_mod_date := CURRENT_DATE;
        NEW.subcategory_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.subcategory_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
       END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER subcategory_trigger BEFORE INSERT OR UPDATE OR DELETE ON subcategory FOR EACH ROW
    EXECUTE PROCEDURE subcategory_checker();

CREATE OR REPLACE VIEW subcategory_combo AS
    SELECT subcategory_id AS id,
        CASE
            WHEN current_date < subcategory_start OR current_date > subcategory_end
            THEN '~ '
            ELSE ''
        END ||
        category_hid || ' -- ' ||  subcategory_name
        AS text
    FROM  category, subcategory
    WHERE subcategory_category = category_id
    ORDER BY text;

GRANT SELECT ON subcategory_combo to group perm_user;

CREATE OR REPLACE VIEW subcategory_list AS
    SELECT  subcategory_id,
            category_hid,
            subcategory_name,
            pers_hid AS subcategory_pers,
            subcategory_start,
            subcategory_end,
            CASE
                WHEN current_date < subcategory_start
                   THEN false
                WHEN current_date > subcategory_end
                   THEN false
                ELSE true
            END AS active
    FROM  category, subcategory, pers
    WHERE subcategory_category = category_id
     AND  subcategory_pers = pers_id;

GRANT SELECT ON subcategory_list TO GROUP perm_user;

COMMENT ON COLUMN subcategory_list.active IS 'Aktiv';


-- ################
-- # Element      #
-- ################

DROP TABLE IF EXISTS element;
DROP SEQUENCE IF EXISTS element_element_id_seq;
CREATE TABLE element (
    element_id          SERIAL NOT NULL PRIMARY KEY,               -- Unique ID
    element_hid         NAME   NOT NULL UNIQUE,                      -- Human Readable Unique ID
    element_name        TEXT   NOT NULL CHECK (element_name != ''),  -- element Name
    element_subcategory INT4   NOT NULL REFERENCES subcategory,
    element_type        INT4   NOT NULL REFERENCES type,                -- what kind of type is this element
    element_pers        INT4   NOT NULL REFERENCES pers DEFAULT pers_hid2id(current_user), -- element Manager
    element_start       DATE   NOT NULL DEFAULT CURRENT_DATE,        -- element start date
    element_end         DATE            CHECK (element_end IS NULL OR element_end > element_start), -- element end date
    element_desc        TEXT   NOT NULL CHECK (element_desc != ''),     -- element Bemerkung
    element_mod_date    DATE,                                 -- last change
    element_mod_user    NAME                                  -- by whom
) WITH OIDS;

GRANT SELECT                      ON element_element_id_seq TO GROUP perm_user;
GRANT SELECT                      ON element                TO GROUP perm_user;
GRANT SELECT,UPDATE               ON element_element_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON element                TO GROUP perm_admin;

COMMENT ON TABLE  element                     IS 'C Elemente';
COMMENT ON COLUMN element.element_id          IS 'ID';
COMMENT ON COLUMN element.element_hid         IS 'Abkuerzung';
COMMENT ON COLUMN element.element_name        IS 'Name';
COMMENT ON COLUMN element.element_subcategory IS 'Subkategorie';
COMMENT ON COLUMN element.element_pers        IS 'Verantwortlich';
COMMENT ON COLUMN element.element_start       IS 'Start';
COMMENT ON COLUMN element.element_end         IS 'End (Ex Element)';
COMMENT ON COLUMN element.element_type        IS 'Type';
COMMENT ON COLUMN element.element_desc        IS 'Bemerkung';
COMMENT ON COLUMN element.element_mod_date    IS 'Veraendert am';
COMMENT ON COLUMN element.element_mod_user    IS 'Veraendert von';

INSERT INTO meta_fields
    VALUES ('element', 'element_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('element', 'element_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('element', 'element_mod_user','widget','readonly');

-- permission check for own entries as user or admin
-- if the user role is allowed to write (check above), then force
-- that only own/owned entries can be modified
CREATE OR REPLACE FUNCTION element_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'INSERT' THEN
        IF NEW.element_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.element_mod_date := CURRENT_DATE;
        NEW.element_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.element_pers != pers_hid2id(current_user)
            AND not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
       END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER element_trigger BEFORE INSERT OR UPDATE OR DELETE ON element FOR EACH ROW
    EXECUTE PROCEDURE element_checker();

CREATE OR REPLACE VIEW element_combo AS
    SELECT element_id AS id,
        CASE
            WHEN current_date < element_start OR current_date > element_end
            THEN '~ '
            ELSE ''
        END ||
        element_name || ' -- ' || category_hid || ' ' || subcategory_hid || ' '
        AS text
    FROM  category, subcategory, element
    WHERE element_subcategory  = subcategory_id
      AND subcategory_category = category_id
    ORDER BY text;

GRANT SELECT ON element_combo to group perm_user;

CREATE OR REPLACE VIEW element_list AS
    SELECT  element_id,
            element_hid,
            element_name,
            category_hid    AS category,
            subcategory_hid AS subcategory,
            pers_hid AS element_pers,
            element_start,
            element_end,
            CASE
                WHEN current_date < element_start
                   THEN false
                WHEN current_date > element_end
                   THEN false
                ELSE true
            END AS active
    FROM category, subcategory, element, pers
    WHERE element_subcategory  = subcategory_id
      AND subcategory_category = category_id
      AND element_pers = pers_id;

GRANT SELECT ON element_list TO GROUP perm_user;

COMMENT ON COLUMN element_list.category IS 'Kategory';
COMMENT ON COLUMN element_list.subcategory IS 'Subkategory';
COMMENT ON COLUMN element_list.active IS 'Aktiv';

-- #################################################################
-- auth Table - All authes are documented
-- #################################################################

DROP TABLE IF EXISTS auth;
DROP SEQUENCE IF EXISTS auth_auth_id_seq;
CREATE TABLE auth (
        auth_id            SERIAL  NOT NULL PRIMARY KEY, -- UNIQUE ID
        auth_persorg       INT4    NOT NULL REFERENCES persorg,
        auth_element       INT4    NOT NULL REFERENCES element,
        auth_start         DATE    NOT NULL DEFAULT CURRENT_DATE,        -- auth start date
        auth_end           DATE             CHECK (auth_end IS NULL OR auth_end > auth_start), -- auth end date
        auth_desc          TEXT    NOT NULL CHECK (auth_desc != ''),
        auth_pers          INT4    NOT NULL REFERENCES pers,   -- auth user ... needed for trigger
        auth_mod_date      DATE,                               -- last change
        auth_mod_user      NAME                                -- by whom
) WITH OIDS;

COMMENT ON TABLE  auth               IS 'F Berechtigungen';
COMMENT ON COLUMN auth.auth_id       IS 'ID';
COMMENT ON COLUMN auth.auth_pers     IS 'FI ID';
COMMENT ON COLUMN auth.auth_persorg  IS 'FI';
COMMENT ON COLUMN auth.auth_element  IS 'Element';
COMMENT ON COLUMN auth.auth_start    IS 'Start';
COMMENT ON COLUMN auth.auth_end      IS 'End (Ex Berechtigung)';
COMMENT ON COLUMN auth.auth_desc     IS 'Bemerkung';
COMMENT ON COLUMN auth.auth_mod_date IS 'Veraendert am';
COMMENT ON COLUMN auth.auth_mod_user IS 'Veraendert von';

GRANT SELECT                      ON auth_auth_id_seq TO GROUP perm_user;
GRANT SELECT                      ON auth               TO GROUP perm_user;
GRANT SELECT,UPDATE               ON auth_auth_id_seq TO GROUP perm_admin;
GRANT SELECT,INSERT,UPDATE,DELETE ON auth               TO GROUP perm_admin;

INSERT INTO meta_fields
    VALUES ('auth', 'auth_desc', 'widget','area');

INSERT INTO meta_fields
    VALUES ('auth', 'auth_pers','widget','readonly');

INSERT INTO meta_fields
    VALUES ('auth', 'auth_mod_date','widget','readonly');

INSERT INTO meta_fields
    VALUES ('auth', 'auth_mod_user','widget','readonly');

CREATE OR REPLACE FUNCTION auth_checker() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.auth_pers     := (SELECT pers_id FROM pers, persorg WHERE persorg_pers = pers_id AND persorg_id = NEW.auth_persorg);
        NEW.auth_mod_date := CURRENT_DATE;
        NEW.auth_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.auth_pers != pers_hid2id(current_user)
            AND NOT ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
        NEW.auth_pers     := (SELECT pers_id FROM pers, persorg WHERE persorg_pers = pers_id AND persorg_id = NEW.auth_persorg);
        NEW.auth_mod_date := CURRENT_DATE;
        NEW.auth_mod_user := getpgusername();
    END IF;

    IF TG_OP = 'UPDATE' or TG_OP = 'DELETE' THEN
        IF  OLD.auth_pers != pers_hid2id(current_user)
            AND  not ( ingroup('perm_admin') )
        THEN
            RAISE EXCEPTION 'Do not change other peoples entries';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END; $$
LANGUAGE 'plpgsql';

CREATE TRIGGER auth_trigger BEFORE INSERT OR UPDATE OR DELETE ON auth FOR EACH ROW
      EXECUTE PROCEDURE auth_checker();

CREATE OR REPLACE VIEW auth_list AS
    SELECT  auth_id,
            pers_hid     AS pers,
            org_hid      AS org,
            element_name AS element,
            auth_start,
            auth_end,
            CASE
                WHEN current_date < auth_start
                   THEN false
                WHEN current_date > auth_end
                   THEN false
                ELSE true
            END AS active
    FROM auth, element, persorg
         LEFT JOIN pers    ON (persorg_pers   = pers_id)
         LEFT JOIN org     ON (persorg_org    = org_id)
    WHERE auth_persorg = persorg_id
      AND auth_element = element_id;

GRANT SELECT ON auth_list TO GROUP perm_user;

COMMENT ON COLUMN auth_list.pers     IS 'Person';
COMMENT ON COLUMN auth_list.org      IS 'Organisation';
COMMENT ON COLUMN auth_list.element  IS 'Element';
COMMENT ON COLUMN auth_list.active   IS 'Aktiv';

-- #################################################################
-- special views
-- #################################################################

-- Person View
CREATE OR REPLACE VIEW all_external_rep AS (
     SELECT persorg_id,
            pers_hid      AS persorg_pers,
            pers_last     AS persorg_last,
            pers_first    AS persorg_first,
            org_hid       AS persorg_org,
            pers_external AS persorg_pers_external,
            org_external  AS persorg_org_external,
            CASE
                WHEN current_date < pers_start
                   THEN false
                WHEN current_date > pers_end
                   THEN false
                WHEN current_date < org_start
                   THEN false
                WHEN current_date > org_end
                   THEN false
                ELSE true
            END AS active
    FROM    persorg, org, pers
    WHERE   persorg_org  = org_id
      AND   persorg_pers = pers_id
      AND   (pers_external IS TRUE OR
             org_external IS TRUE)
   ORDER BY persorg_pers
);
GRANT SELECT ON all_external_rep TO GROUP perm_user;
COMMENT ON VIEW all_external_rep IS 'Alle externen Funktionsinhaber';

COMMENT ON COLUMN all_external_rep.persorg_pers_external IS 'Externe Person';
COMMENT ON COLUMN all_external_rep.persorg_org_external  IS 'Externe Organisation';
COMMENT ON COLUMN all_external_rep.active                IS 'Aktiv';

-- Things View
CREATE OR REPLACE VIEW all_things_combination_rep AS (
    SELECT  category_hid AS category,
            subcategory_hid AS subcategory,
            element_name AS element,
            CASE
                WHEN current_date < element_start
                   THEN false
                WHEN current_date > element_end
                   THEN false
                ELSE true
            END AS active
    FROM    category, subcategory, element
    WHERE   element_subcategory  = subcategory_id
      AND   subcategory_category = category_id
   ORDER BY category, subcategory, element_hid
);
GRANT SELECT ON all_things_combination_rep TO GROUP perm_user;
COMMENT ON VIEW all_things_combination_rep IS 'Alle Kategorien und Elemente';

COMMENT ON COLUMN all_things_combination_rep.subcategory IS 'Subkategorie';
COMMENT ON COLUMN all_things_combination_rep.subcategory IS 'Element';
COMMENT ON COLUMN all_things_combination_rep.active IS 'Aktiv';


-- EOF

--   Perm is a permission and access management system with RDMS.
--   Copyright (C) 2015-2019, Stiftung 3FO, CH-4600 Olten
--   Copyright (C) 2015-2019, Forem AG, CH-4600 Olten
--   Copyright (C) 2015-2019, Roman Plessl (prunux.ch)
--
--   This program is free software: you can redistribute it and/or modify
--   it under the terms of the GNU General Public License as published by
--   the Free Software Foundation, either version 3 of the License, or
--   (at your option) any later version.
--
--   This program is distributed in the hope that it will be useful,
--   but WITHOUT ANY WARRANTY; without even the implied warranty of
--   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--   GNU General Public License for more details.
--
--   You should have received a copy of the GNU General Public License
--   along with this program.  If not, see <https://www.gnu.org/licenses/>.
