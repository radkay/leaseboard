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
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: unit_status_as_of(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unit_status_as_of(as_of date) RETURNS TABLE(unit_id bigint, property_id bigint, unit_number character varying, bedrooms integer, market_rent numeric, status text, current_lease_id bigint, current_monthly_rent numeric, current_lease_end_date date, notice_date date, move_out_date date, next_lease_start_date date, as_of date)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  WITH current_lease AS (
    SELECT DISTINCT ON (l.unit_id)
      l.unit_id, l.id, l.resident_id, l.status, l.monthly_rent, l.end_date, l.notice_date, l.move_out_date
    FROM leases l
    WHERE l.status IN ('active', 'notice_given')
      AND as_of BETWEEN l.start_date AND l.end_date
    ORDER BY l.unit_id, l.start_date DESC
  ),
  next_pending AS (
    SELECT DISTINCT ON (l.unit_id) l.unit_id, l.start_date
    FROM leases l
    WHERE l.status = 'pending'
    ORDER BY l.unit_id, l.start_date ASC
  )
  SELECT
    u.id, u.property_id, u.number, u.bedrooms, u.market_rent,
    CASE
      WHEN cl.status = 'active' THEN 'occupied'
      WHEN cl.status = 'notice_given' AND np.unit_id IS NOT NULL THEN 'on_notice_rented'
      WHEN cl.status = 'notice_given' THEN 'on_notice'
      WHEN cl.unit_id IS NULL AND np.unit_id IS NOT NULL THEN 'vacant_rented'
      ELSE 'vacant_available'
    END,
    cl.id,
    cl.monthly_rent, cl.end_date, cl.notice_date, cl.move_out_date,
    np.start_date, as_of
  FROM units u
  LEFT JOIN current_lease cl ON cl.unit_id = u.id
  LEFT JOIN next_pending  np ON np.unit_id = u.id
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: leases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leases (
    id bigint NOT NULL,
    unit_id bigint NOT NULL,
    resident_id bigint NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    monthly_rent numeric(10,2) NOT NULL,
    status character varying NOT NULL,
    notice_date date,
    move_out_date date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT leases_end_after_start CHECK ((end_date > start_date)),
    CONSTRAINT leases_monthly_rent_positive CHECK ((monthly_rent > (0)::numeric)),
    CONSTRAINT leases_status_valid CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'active'::character varying, 'notice_given'::character varying, 'ended'::character varying])::text[])))
);


--
-- Name: properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.properties (
    id bigint NOT NULL,
    name character varying NOT NULL,
    address character varying NOT NULL,
    city character varying NOT NULL,
    state character varying NOT NULL,
    sanity_slug character varying,
    units_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.units (
    id bigint NOT NULL,
    property_id bigint NOT NULL,
    number character varying NOT NULL,
    bedrooms integer NOT NULL,
    bathrooms numeric(3,1) NOT NULL,
    sq_ft integer NOT NULL,
    market_rent numeric(10,2) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT units_bathrooms_positive CHECK ((bathrooms > (0)::numeric)),
    CONSTRAINT units_bedrooms_non_negative CHECK ((bedrooms >= 0)),
    CONSTRAINT units_market_rent_positive CHECK ((market_rent > (0)::numeric)),
    CONSTRAINT units_sq_ft_positive CHECK ((sq_ft > 0))
);


--
-- Name: lease_expirations_12m; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.lease_expirations_12m AS
 WITH months AS (
         SELECT (((date_trunc('month'::text, (CURRENT_DATE)::timestamp with time zone))::date + ((n.n || ' months'::text))::interval))::date AS month
           FROM generate_series(0, 11) n(n)
        ), expiring AS (
         SELECT u.property_id,
            (date_trunc('month'::text, (l.end_date)::timestamp with time zone))::date AS month,
            (EXISTS ( SELECT 1
                   FROM public.leases nl
                  WHERE ((nl.unit_id = l.unit_id) AND ((nl.status)::text = 'pending'::text) AND (nl.start_date > l.end_date)))) AS has_followon
           FROM (public.leases l
             JOIN public.units u ON ((u.id = l.unit_id)))
          WHERE ((l.status)::text = ANY ((ARRAY['active'::character varying, 'notice_given'::character varying])::text[]))
        )
 SELECT p.id AS property_id,
    m.month,
    count(e.has_followon) AS expiring_total,
    count(*) FILTER (WHERE e.has_followon) AS expiring_renewed_or_relet,
    count(*) FILTER (WHERE (e.has_followon IS FALSE)) AS expiring_open
   FROM ((public.properties p
     CROSS JOIN months m)
     LEFT JOIN expiring e ON (((e.property_id = p.id) AND (e.month = m.month))))
  GROUP BY p.id, m.month;


--
-- Name: leases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.leases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: leases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.leases_id_seq OWNED BY public.leases.id;


--
-- Name: properties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.properties_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.properties_id_seq OWNED BY public.properties.id;


--
-- Name: unit_status_today; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.unit_status_today AS
 SELECT unit_id,
    property_id,
    unit_number,
    bedrooms,
    market_rent,
    status,
    current_monthly_rent,
    current_lease_end_date,
    notice_date,
    move_out_date,
    next_lease_start_date,
    as_of
   FROM public.unit_status_as_of(CURRENT_DATE) unit_status_as_of(unit_id, property_id, unit_number, bedrooms, market_rent, status, current_lease_id, current_monthly_rent, current_lease_end_date, notice_date, move_out_date, next_lease_start_date, as_of);


--
-- Name: property_kpis_today; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.property_kpis_today AS
 SELECT p.id AS property_id,
    count(ust.unit_id) AS total_units,
    count(*) FILTER (WHERE (ust.status = 'occupied'::text)) AS occupied,
    count(*) FILTER (WHERE (ust.status = 'on_notice'::text)) AS on_notice,
    count(*) FILTER (WHERE (ust.status = 'on_notice_rented'::text)) AS on_notice_rented,
    count(*) FILTER (WHERE (ust.status = 'vacant_rented'::text)) AS vacant_rented,
    count(*) FILTER (WHERE (ust.status = 'vacant_available'::text)) AS vacant_available,
        CASE
            WHEN (count(ust.unit_id) = 0) THEN (0)::numeric
            ELSE round(((100.0 * (count(*) FILTER (WHERE (ust.status = ANY (ARRAY['occupied'::text, 'on_notice'::text, 'on_notice_rented'::text]))))::numeric) / (count(ust.unit_id))::numeric), 2)
        END AS occupancy_pct,
        CASE
            WHEN (count(ust.unit_id) = 0) THEN (0)::numeric
            ELSE round(((100.0 * (count(*) FILTER (WHERE (ust.status = ANY (ARRAY['occupied'::text, 'on_notice_rented'::text, 'vacant_rented'::text]))))::numeric) / (count(ust.unit_id))::numeric), 2)
        END AS leased_pct,
    count(*) FILTER (WHERE (ust.status = ANY (ARRAY['vacant_available'::text, 'on_notice'::text]))) AS available_units
   FROM (public.properties p
     LEFT JOIN public.unit_status_today ust ON ((ust.property_id = p.id)))
  GROUP BY p.id;


--
-- Name: property_unit_type_kpis_today; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.property_unit_type_kpis_today AS
 SELECT property_id,
    bedrooms,
    count(unit_id) AS total_units,
    count(*) FILTER (WHERE (status = 'occupied'::text)) AS occupied,
    count(*) FILTER (WHERE (status = 'on_notice'::text)) AS on_notice,
    count(*) FILTER (WHERE (status = 'on_notice_rented'::text)) AS on_notice_rented,
    count(*) FILTER (WHERE (status = 'vacant_rented'::text)) AS vacant_rented,
    count(*) FILTER (WHERE (status = 'vacant_available'::text)) AS vacant_available,
        CASE
            WHEN (count(unit_id) = 0) THEN (0)::numeric
            ELSE round(((100.0 * (count(*) FILTER (WHERE (status = ANY (ARRAY['occupied'::text, 'on_notice'::text, 'on_notice_rented'::text]))))::numeric) / (count(unit_id))::numeric), 2)
        END AS occupancy_pct,
        CASE
            WHEN (count(unit_id) = 0) THEN (0)::numeric
            ELSE round(((100.0 * (count(*) FILTER (WHERE (status = ANY (ARRAY['occupied'::text, 'on_notice_rented'::text, 'vacant_rented'::text]))))::numeric) / (count(unit_id))::numeric), 2)
        END AS leased_pct,
    count(*) FILTER (WHERE (status = ANY (ARRAY['vacant_available'::text, 'on_notice'::text]))) AS available_units
   FROM public.unit_status_today ust
  GROUP BY property_id, bedrooms;


--
-- Name: residents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.residents (
    id bigint NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email character varying NOT NULL,
    phone character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: residents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.residents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: residents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.residents_id_seq OWNED BY public.residents.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.units_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.units_id_seq OWNED BY public.units.id;


--
-- Name: leases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leases ALTER COLUMN id SET DEFAULT nextval('public.leases_id_seq'::regclass);


--
-- Name: properties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties ALTER COLUMN id SET DEFAULT nextval('public.properties_id_seq'::regclass);


--
-- Name: residents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residents ALTER COLUMN id SET DEFAULT nextval('public.residents_id_seq'::regclass);


--
-- Name: units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units ALTER COLUMN id SET DEFAULT nextval('public.units_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: leases leases_no_overlapping_live_leases; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leases
    ADD CONSTRAINT leases_no_overlapping_live_leases EXCLUDE USING gist (unit_id WITH =, daterange(start_date, end_date, '[]'::text) WITH &&) WHERE (((status)::text <> 'ended'::text));


--
-- Name: leases leases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leases
    ADD CONSTRAINT leases_pkey PRIMARY KEY (id);


--
-- Name: properties properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.properties
    ADD CONSTRAINT properties_pkey PRIMARY KEY (id);


--
-- Name: residents residents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.residents
    ADD CONSTRAINT residents_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: units units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT units_pkey PRIMARY KEY (id);


--
-- Name: index_leases_on_resident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leases_on_resident_id ON public.leases USING btree (resident_id);


--
-- Name: index_leases_on_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_leases_on_unit_id ON public.leases USING btree (unit_id);


--
-- Name: index_properties_on_sanity_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_properties_on_sanity_slug ON public.properties USING btree (sanity_slug) WHERE (sanity_slug IS NOT NULL);


--
-- Name: index_residents_on_lower_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_residents_on_lower_email ON public.residents USING btree (lower((email)::text));


--
-- Name: index_units_on_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_units_on_property_id ON public.units USING btree (property_id);


--
-- Name: index_units_on_property_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_units_on_property_id_and_number ON public.units USING btree (property_id, number);


--
-- Name: leases fk_rails_29210439a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leases
    ADD CONSTRAINT fk_rails_29210439a5 FOREIGN KEY (unit_id) REFERENCES public.units(id);


--
-- Name: units fk_rails_d7df365ccb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.units
    ADD CONSTRAINT fk_rails_d7df365ccb FOREIGN KEY (property_id) REFERENCES public.properties(id);


--
-- Name: leases fk_rails_f7dbe61ba2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leases
    ADD CONSTRAINT fk_rails_f7dbe61ba2 FOREIGN KEY (resident_id) REFERENCES public.residents(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261122012444'),
('20261122005325'),
('20261122002440'),
('20261122001704'),
('20261122000537'),
('20261122000532'),
('20261122000528'),
('20261122000524');

