CREATE SEQUENCE ecode_sq AS INTEGER INCREMENT BY 1 MINVALUE 1 START 1 CYCLE;


CREATE DOMAIN SEX as CHAR CHECK(VALUE = 'F' OR VALUE = 'M');
CREATE DOMAIN POSTINT AS INTEGER CHECK(VALUE > 0);

CREATE TABLE doctor (
        ecode INTEGER default nextval('ecode_sq'),  --ecode SERIAL NOT NULL,
        lname VARCHAR(20) NOT NULL,
        fname VARCHAR(20) NOT NULL,
        dob DATE NOT NULL,
        address VARCHAR NOT NULL,
        gender SEX NOT NULL,
        start_date DATE NOT NULL,
        degree_name VARCHAR(100) NOT NULL,
        degree_year SMALLINT NOT NULL CHECK (degree_year >= 1900 AND degree_year <= extract(year from current_date)),
        dcode SMALLINT NOT NULL,
        PRIMARY KEY (ecode)
);
-- alter table doctor alter column address set not null;
-- alter table doctor alter column address set not null;
-- alter table doctor alter column degree_year type smallint;
-- alter table doctor alter column dcode type smallint;

CREATE TABLE department (
        dcode smallserial NOT NULL,
		dtitle VARCHAR(100) NOT NULL UNIQUE, -- weird if two departments having a same name
        -- dtitle VARCHAR(100) NOT NULL,
        mgr_code INTEGER,
        PRIMARY KEY (dcode)
);
-- ALTER TABLE department alter column dcode type smallint;

-- cascade because if an employee does not belong to any department when commit, it is invalid
ALTER TABLE doctor ADD CONSTRAINT fk_doctor_dcode FOREIGN KEY(dcode) REFERENCES department (dcode)
ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE;
ALTER TABLE department ADD CONSTRAINT fk_department_mgr_code FOREIGN KEY(mgr_code) REFERENCES doctor (ecode)
ON UPDATE CASCADE ON DELETE SET NULL;

CREATE TABLE nurse (
        ecode INTEGER default nextval('ecode_sq'),-- ecode SERIAL NOT NULL,
        lname VARCHAR(20) NOT NULL,
        fname VARCHAR(20) NOT NULL,
        dob DATE NOT NULL,
        address VARCHAR NOT NULL,
        gender SEX NOT NULL,
        start_date DATE NOT NULL,
        degree_name VARCHAR(100) NOT NULL,
        degree_year SMALLINT NOT NULL CHECK (degree_year >= 1900 AND degree_year <= extract(year from current_date)),
        dcode SMALLINT NOT NULL,
        PRIMARY KEY (ecode),
		CONSTRAINT fk_nurse_dcode FOREIGN KEY(dcode) REFERENCES department (dcode) ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE
        -- CONSTRAINT fk_nurse_dcode FOREIGN KEY(dcode) REFERENCES department (dcode)
);
-- alter table nurse alter column dob set not null;
-- alter table nurse alter column address set not null;
-- alter table nurse alter column degree_year type smallint;
-- alter table nurse alter column dcode type smallint;

CREATE TABLE doctor_phone (
        ecode INTEGER NOT NULL,
        phone_num CHAR(10), --they may not have a phone, or phone number is wrong and need to be reviewed
        PRIMARY KEY (ecode, phone_num),
		FOREIGN KEY(ecode) REFERENCES doctor (ecode) ON UPDATE CASCADE ON DELETE CASCADE
        -- FOREIGN KEY(ecode) REFERENCES doctor (ecode)
);

-- alter table doctor_phone alter column phone_num type char(10);

CREATE TABLE nurse_phone (
        ecode INTEGER NOT NULL,
        phone_num CHAR(10),--they may not have a phone, or phone number is wrong and need to be reviewed
        PRIMARY KEY (ecode, phone_num),
		FOREIGN KEY(ecode) REFERENCES nurse (ecode) ON UPDATE CASCADE ON DELETE CASCADE
        -- FOREIGN KEY(ecode) REFERENCES doctor (ecode)
);
-- alter table nurse_phone alter column phone_num type char(10);

CREATE SEQUENCE pid_sq INCREMENT BY 1 START WITH 1 MINVALUE 1 MAXVALUE 999999999 CYCLE;
CREATE TABLE inpatient (
        pid INTEGER default nextval('pid_sq'),
        ipid CHAR(11),
        lname VARCHAR(20) NOT NULL,
        fname VARCHAR(20) NOT NULL,
        dob DATE NOT NULL,
        address VARCHAR,
        phone CHAR(10),
        gender SEX NOT NULL,
        PRIMARY KEY (pid)
);

CREATE TABLE outpatient (
        pid INTEGER default nextval('pid_sq'),
        opid CHAR(11),
        lname VARCHAR(20) NOT NULL,
        fname VARCHAR(20) NOT NULL,
        dob DATE NOT NULL,
        address VARCHAR,
        phone CHAR(10), -- some one may have no phone
        gender SEX NOT NULL,
        PRIMARY KEY (pid)
);

-- alter table inpatient alter column ipid type char(11);
-- alter table outpatient alter column opid type char(11);

CREATE TABLE provider (
		pnum SERIAL PRIMARY KEY,
		pname VARCHAR(50) NOT NULL,
		phone CHAR(10),
		address VARCHAR NOT NULL
);
-- ALTER TABLE provider ALTER COLUMN pname TYPE varchar (50);
-- alter table provider alter column address set not null;


CREATE TABLE batch (
		batch_id SERIAL PRIMARY KEY,
		imported_date DATE NOT NULL,
		provider_num INTEGER NOT NULL,
		CONSTRAINT fk_batch_provider_pnum FOREIGN KEY (provider_num) REFERENCES provider(pnum) ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE
);

CREATE TABLE medication (
		medication_id SERIAL PRIMARY KEY,
		name VARCHAR(100) NOT NULL,  --name does not need to be unique since meds can come with different sizes
		price POSTINT NOT NULL
);

CREATE TABLE contain(
		batch_num INTEGER NOT NULL,
		med_num INTEGER NOT NULL,
		imported_price INTEGER NOT NULL,
		imported_quantity INTEGER NOT NULL, --per unit
		exp_date DATE NOT NULL,
		exp_flag BOOLEAN NOT NULL DEFAULT FALSE, -- can be unknown
		PRIMARY KEY (batch_num, med_num),
		CONSTRAINT fk_contain_batch_batch_num FOREIGN KEY (batch_num) REFERENCES batch(batch_id) ON UPDATE CASCADE ON DELETE RESTRICT,
		-- no batch should be deleted if there are still medicine recorded come from it
		CONSTRAINT fk_contain_med_num FOREIGN KEY (med_num) REFERENCES medication(medication_id) ON UPDATE CASCADE ON DELETE RESTRICT
		-- no medication should be deleted if they are imported from a batch that is still in database
);

CREATE TABLE medication_effect (
		med_num INTEGER NOT NULL,
		effect VARCHAR(100) NOT NULL, --a couple of words, each row stand for a single effect
		PRIMARY KEY (med_num, effect),
		CONSTRAINT fk_effect_med_mnum FOREIGN KEY (med_num) REFERENCES medication(medication_id) ON UPDATE CASCADE ON DELETE CASCADE
);


CREATE TABLE treatment (
        sid SERIAL NOT NULL,
        start_date DATE NOT NULL,
        end_date DATE CHECK (NULL OR end_date >= start_date),
        result VARCHAR(200),-- result VARCHAR(100),
        recover_f BOOLEAN NOT NULL DEFAULT FALSE,
        med_f BOOLEAN NOT NULL DEFAULT FALSE,
		-- total_medication_price INTEGER,
        PRIMARY KEY (sid)
);
-- ALTER TABLE treatment DROP COLUMN total_medication_price;


CREATE TABLE admission (
		pid INTEGER NOT NULL,
		date_of_adm DATE NOT NULL,
		PRIMARY KEY(pid, date_of_adm),
		date_of_disc DATE CHECK (NULL OR  date_of_adm <= date_of_disc),
		room VARCHAR NOT NULL,
		nurse_id INTEGER NOT NULL,
		diagnosis VARCHAR,
		fee INTEGER NOT NULL CHECK (fee >= 0),
		CONSTRAINT fk_adm_inp_pid FOREIGN KEY (pid) REFERENCES inpatient(pid) ON UPDATE CASCADE ON DELETE CASCADE,
		CONSTRAINT fk_adm_nurse FOREIGN KEY (nurse_id) REFERENCES nurse(ecode) ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE
		-- DEFERRABLE because maybe a nurse is not being assigned yet
);

CREATE TABLE treat  (
		pid INTEGER NOT NULL,
		date_of_adm DATE NOT NULL,
		did INTEGER NOT NULL,
		sid INTEGER NOT NULL,
		PRIMARY KEY (did,sid),
		CONSTRAINT fk_treat_adm_pid FOREIGN KEY (pid, date_of_adm) REFERENCES admission(pid, date_of_adm) ON UPDATE CASCADE ON DELETE CASCADE,
		CONSTRAINT fk_treat_doctor_id FOREIGN KEY (did) REFERENCES doctor(ecode) ON UPDATE CASCADE ON DELETE RESTRICT DEFERRABLE,
		CONSTRAINT fk_treat_treatment_sid FOREIGN KEY (sid) REFERENCES treatment(sid) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE t_consists_of (
		sid INTEGER NOT NULL,
		mid INTEGER NOT NULL,
		quantity POSTINT NOT NULL,
		PRIMARY KEY(sid,mid),
		CONSTRAINT fk_tcon_treatment_sid FOREIGN KEY (sid) REFERENCES treatment(sid) ON UPDATE CASCADE ON DELETE CASCADE,
		CONSTRAINT fk_tcon_med_mid FOREIGN KEY (mid) REFERENCES medication(medication_id) ON UPDATE CASCADE ON DELETE RESTRICT
);



-- DELETE FROM outpatient where pid = 1;
-- INSERT INTO outpatient (lname, fname, dob, address, phone, gender) VALUES
-- 	('Nguyen', 'Sinh', '1974-10-09', '16 Ly Tu Trong, District 1, Ho Chi Minh City', '028463779222','M');

-- -- -- testing: this will raise error because data is inconsistent
-- -- INSERT INTO outpatient (pid, lname, fname, dob, address, phone, gender) VALUES
-- -- 	(1, 'Nguyen', 'a', '1974-10-09', '16 Ly Tu Trong, District 1, Ho Chi Minh City', '028463779222','M');

-- -- -- test update consistency
-- UPDATE outpatient set fname = 'Kinh' where pid =2 ;
-- -- update inpatient set lname = 'Tran' where pid = 1;

-- -- -- quick way to insert and also help ensure consistency
-- SELECT insert_patient(1, 'outpatient');
-- SELECT insert_patient(2, 'inpatient');

-- select * from inpatient;
-- select * from outpatient;

CREATE TABLE examination (
        sid SERIAL NOT NULL,
		fee INTEGER NOT NULL CHECK (fee >= 0), -- bout 9 billion is the maximum
		e_date DATE NOT NULL,
		diagnosis VARCHAR(200),
		next_exam_date DATE CHECK (NULL OR next_exam_date >= e_date),
		pid INTEGER NOT NULL,
		did INTEGER NOT NULL,
		med_f BOOLEAN NOT NULL DEFAULT FALSE,
		PRIMARY KEY (sid),
		CONSTRAINT fk_exam_outp_pid FOREIGN KEY (pid) REFERENCES outpatient (pid) ON UPDATE CASCADE ON DELETE CASCADE,
		CONSTRAINT fk_exam_doctor_did FOREIGN KEY (did) REFERENCES doctor (ecode) ON UPDATE CASCADE ON DELETE SET NULL -- NOT SURE
);

CREATE TABLE e_consists_of (
		sid INTEGER NOT NULL,
		mid INTEGER NOT NULL,
		quantity POSTINT NOT NULL,
		PRIMARY KEY(sid,mid),
		CONSTRAINT fk_econ_examination_sid FOREIGN KEY (sid) REFERENCES examination(sid) ON UPDATE CASCADE ON DELETE CASCADE,
		CONSTRAINT fk_econ_med_mid FOREIGN KEY (mid) REFERENCES medication(medication_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- insert into treatment (start_date) values
-- 	(current_date);
-- ;







