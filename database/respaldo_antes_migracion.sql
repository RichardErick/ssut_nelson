--
-- PostgreSQL database dump
--

-- Dumped from database version 14.9
-- Dumped by pg_dump version 17.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: update_modified_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_modified_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_modified_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: tarjetas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tarjetas (
    id integer NOT NULL,
    nombre_completo character varying(255) NOT NULL,
    numero_identificacion character varying(50) NOT NULL,
    cargo_departamento character varying(100) NOT NULL,
    fecha_emision date DEFAULT CURRENT_DATE NOT NULL,
    fecha_vencimiento date,
    estado character varying(20) DEFAULT 'Activa'::character varying NOT NULL,
    foto_url character varying(255),
    qr_code_url character varying(255),
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT tarjetas_estado_check CHECK (((estado)::text = ANY ((ARRAY['Activa'::character varying, 'Inactiva'::character varying, 'Vencida'::character varying])::text[])))
);


ALTER TABLE public.tarjetas OWNER TO postgres;

--
-- Name: tarjetas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tarjetas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tarjetas_id_seq OWNER TO postgres;

--
-- Name: tarjetas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tarjetas_id_seq OWNED BY public.tarjetas.id;


--
-- Name: tarjetas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarjetas ALTER COLUMN id SET DEFAULT nextval('public.tarjetas_id_seq'::regclass);


--
-- Data for Name: tarjetas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tarjetas (id, nombre_completo, numero_identificacion, cargo_departamento, fecha_emision, fecha_vencimiento, estado, foto_url, qr_code_url, created_at, updated_at) FROM stdin;
\.


--
-- Name: tarjetas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tarjetas_id_seq', 1, false);


--
-- Name: tarjetas tarjetas_numero_identificacion_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarjetas
    ADD CONSTRAINT tarjetas_numero_identificacion_key UNIQUE (numero_identificacion);


--
-- Name: tarjetas tarjetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tarjetas
    ADD CONSTRAINT tarjetas_pkey PRIMARY KEY (id);


--
-- Name: idx_tarjetas_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tarjetas_estado ON public.tarjetas USING btree (estado);


--
-- Name: idx_tarjetas_numero_identificacion; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tarjetas_numero_identificacion ON public.tarjetas USING btree (numero_identificacion);


--
-- Name: tarjetas update_tarjetas_modtime; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_tarjetas_modtime BEFORE UPDATE ON public.tarjetas FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

