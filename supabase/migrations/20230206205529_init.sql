CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

CREATE TABLE category
(
    id   integer PRIMARY KEY,
    name text NOT NULL
);

INSERT INTO category (id, name)
VALUES (1, 'Elektronik & Technik'),
       (2, 'Unterhaltung & Gaming'),
       (3, 'Lebensmittel & Haushalt'),
       (4, 'Fashion, Schmuck & Lifestyle'),
       (5, 'Beauty, Wellness & Gesundheit'),
       (6, 'Family & Kids'),
       (7, 'Home & Living'),
       (8, 'Baumarkt & Garten'),
       (9, 'Auto, Fahhrad & Motorrad'),
       (10, 'Gastronomie, Bars & Cafes'),
       (11, 'Kultur & Freizeit'),
       (12, 'Sport & Outdoor'),
       (13, 'Reisen, Hotels & Übernachtungen'),
       (14, 'Dienstleistungen & Finanzen'),
       (15, 'Floristik'),
       (16, 'Sonstiges');

CREATE TABLE IF NOT EXISTS account
(
    id                   uuid                  NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    dealer               bool                  NOT NULL DEFAULT false,
    street               text                  NULL,
    username             text                  NULL,
    age                  integer               NULL,
    gender               text                  NULL,
    company_name         text                  NULL,
    default_category     integer               NULL REFERENCES category (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    house_number         text                  NULL,
    city                 text                  NULL,
    zip                  integer               NULL,
    phone                text                  NULL,
    tax_id               text                  NULL,
    use_current_location bool                  NULL DEFAULT false,
    search_radius        integer               NULL DEFAULT 500,
    selected_categories  integer[]             NULL,
    "location"           geometry(point, 4326) NULL
);

CREATE UNIQUE INDEX account_username_idx ON account (LOWER(username));
CREATE UNIQUE INDEX account_company_name_idx ON account (LOWER(company_name));
CREATE INDEX account_location_idx ON account USING GIST (location);

CREATE TABLE deal
(
    id          uuid        NOT NULL DEFAULT uuid_generate_v4() PRIMARY KEY,
    dealer_id   uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    title       text        NOT NULL,
    description text        NOT NULL,
    category_id integer     NOT NULL REFERENCES category (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    "duration"  integer     NOT NULL,
    "start"     timestamptz NOT NULL,
    "template"  bool        NOT NULL DEFAULT false,
    created     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE dealer_rating
(
    user_id     uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    dealer_id   uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    stars       integer     NOT NULL,
    rating_text text        NULL,
    created     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "dealer_rating_pk" UNIQUE (user_id, dealer_id)
);

CREATE TABLE hot_deal
(
    user_id uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    deal_id uuid        NOT NULL REFERENCES deal (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    created timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "hot_deal_pk" UNIQUE (user_id, deal_id)
);

CREATE TABLE reported_deal
(
    reporter_id uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    deal_id     uuid        NOT NULL REFERENCES deal (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    reason      text        NOT NULL,
    created     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "reported_deal_pk" UNIQUE (reporter_id, deal_id)
);

CREATE TABLE favorite_dealer
(
    user_id   uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    dealer_id uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    created   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "favorite_dealer_pk" UNIQUE (user_id, dealer_id)
);

CREATE TABLE "like"
(
    user_id uuid        NOT NULL REFERENCES account (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    deal_id uuid        NOT NULL REFERENCES deal (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    created timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT "like_pk" UNIQUE (user_id, deal_id)
);

CREATE VIEW like_count AS
  SELECT deal_id, count(deal_id) AS likes
  FROM "like"
  GROUP BY deal_id
  ORDER BY likes DESC;

CREATE VIEW dealer AS
  SELECT id, company_name, street, house_number, zip, city
  FROM account
  WHERE dealer IS TRUE;

CREATE OR REPLACE FUNCTION handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $$
begin
  insert into account (
    id, 
    username,
    dealer,
    default_category,
    company_name,
    street,
    house_number,
    city,
    zip,
    phone,
    age,
    gender,
    tax_id
  ) values (
    new.id,
    new.raw_user_meta_data->>'username',
    (new.raw_user_meta_data->>'isDealer')::boolean,
    (new.raw_user_meta_data->>'defaultCategory')::integer,
    new.raw_user_meta_data->>'companyName',
    new.raw_user_meta_data->>'street',
    new.raw_user_meta_data->>'houseNumber',
    new.raw_user_meta_data->>'city',
    (new.raw_user_meta_data->>'zip')::integer,
    new.raw_user_meta_data->>'phone',
    (new.raw_user_meta_data->>'age')::integer,
    new.raw_user_meta_data->>'gender',
    new.raw_user_meta_data->>'taxId'
  );
  return new;
end;
$$;

CREATE OR REPLACE FUNCTION get_favorite_dealers()
 RETURNS SETOF record
 LANGUAGE sql
AS $$
  SELECT a.id, a.company_name 
  FROM account a, favorite_dealer f 
  WHERE a.id = f.dealer_id AND f.user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION get_favorite_dealer_deals()
 RETURNS SETOF record
 LANGUAGE sql
AS $$
  SELECT d.*, a.company_name
  FROM deal d 
  JOIN favorite_dealer f ON d.dealer_id = f.dealer_id
  JOIN account a ON a.id = d.dealer_id
  WHERE now() between d."start" and d."start" + (d."duration" || ' hours')::interval AND f.user_id = auth.uid();
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
