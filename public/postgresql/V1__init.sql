CREATE EXTENSION IF NOT EXISTS "pgcrypto";    




-- object: public.limit_type | type: TYPE --
-- DROP TYPE IF EXISTS public.limit_type CASCADE;
CREATE TYPE public.limit_type AS
 ENUM ('entity','product','transaction','account');
-- ddl-end --
ALTER TYPE public.limit_type OWNER TO postgres;
-- ddl-end --
COMMENT ON TYPE public.limit_type IS 'Limit type';
-- ddl-end --

-- -- object: public.product_id_seq | type: SEQUENCE --
-- -- DROP SEQUENCE IF EXISTS public.product_id_seq CASCADE;
-- CREATE SEQUENCE public.product_id_seq
-- 	INCREMENT BY 1
-- 	MINVALUE 1
-- 	MAXVALUE 9223372036854775807
-- 	START WITH 1
-- 	CACHE 1
-- 	NO CYCLE
-- 	OWNED BY NONE;
-- -- ddl-end --
-- ALTER SEQUENCE public.product_id_seq OWNER TO postgres;
-- -- ddl-end --
-- 
-- object: public.crm | type: TABLE --
-- DROP TABLE IF EXISTS public.crm CASCADE;
CREATE TABLE public.crm (

);
-- ddl-end --
ALTER TABLE public.crm OWNER TO postgres;
-- ddl-end --

-- object: public.schedule | type: TABLE --
-- DROP TABLE IF EXISTS public.schedule CASCADE;
CREATE TABLE public.schedule (

);
-- ddl-end --
ALTER TABLE public.schedule OWNER TO postgres;
-- ddl-end --

-- object: public.notification_type | type: TYPE --
-- DROP TYPE IF EXISTS public.notification_type CASCADE;
CREATE TYPE public.notification_type AS
 ENUM ('authentication','transaction','account','product');
-- ddl-end --
ALTER TYPE public.notification_type OWNER TO postgres;
-- ddl-end --
COMMENT ON TYPE public.notification_type IS 'Type of notification';
-- ddl-end --

-- object: public.aml_type | type: TYPE --
-- DROP TYPE IF EXISTS public.aml_type CASCADE;
CREATE TYPE public.aml_type AS
 ENUM ('daily_limit','weekly_limit','monthly_limit','country_blacklist','country_greylist','person_pep','person_blacklist','person_greylist');
-- ddl-end --
ALTER TYPE public.aml_type OWNER TO postgres;
-- ddl-end --
COMMENT ON TYPE public.aml_type IS 'Type of AML: limit, person, country';
-- ddl-end --

-- object: public.treasury | type: TABLE --
-- DROP TABLE IF EXISTS public.treasury CASCADE;
CREATE TABLE public.treasury (

);
-- ddl-end --
ALTER TABLE public.treasury OWNER TO postgres;
-- ddl-end --

-- object: public.payment_mechanisms | type: TABLE --
-- DROP TABLE IF EXISTS public.payment_mechanisms CASCADE;
CREATE TABLE public.payment_mechanisms (

);
-- ddl-end --
ALTER TABLE public.payment_mechanisms OWNER TO postgres;
-- ddl-end --

-- object: public.indicator | type: TABLE --
-- DROP TABLE IF EXISTS public.indicator CASCADE;
CREATE TABLE public.indicator (

);
-- ddl-end --
ALTER TABLE public.indicator OWNER TO postgres;
-- ddl-end --




-- -- object: public.product_fee_id_seq | type: SEQUENCE --
-- -- DROP SEQUENCE IF EXISTS public.product_fee_id_seq CASCADE;
-- CREATE SEQUENCE public.product_fee_id_seq
-- 	INCREMENT BY 1
-- 	MINVALUE 1
-- 	MAXVALUE 9223372036854775807
-- 	START WITH 1
-- 	CACHE 1
-- 	NO CYCLE
-- 	OWNED BY NONE;
-- -- ddl-end --
-- ALTER SEQUENCE public.product_fee_id_seq OWNER TO postgres;
-- -- ddl-end --
-- 
-- object: public.account_role | type: TYPE --
-- DROP TYPE IF EXISTS public.account_role CASCADE;
CREATE TYPE public.account_role AS
 ENUM ('owner','manager','register');
-- ddl-end --
ALTER TYPE public.account_role OWNER TO postgres;
-- ddl-end --

