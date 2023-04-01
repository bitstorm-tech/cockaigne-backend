create extension if not exists postgis
with
  schema extensions;

create table
  categories (id integer primary key, name text not null);

insert into
  categories (id, name)
values
  (1, 'Elektronik & Technik'),
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

create table if not exists
  accounts (
    id uuid not null default uuid_generate_v4 () primary key,
    email text not null,
    dealer boolean not null default false,
    street text null,
    username text not null,
    age integer null,
    gender text null,
    default_category integer null references categories (id) on delete restrict on update cascade,
    house_number text null,
    city text null,
    zip integer null,
    phone text null,
    tax_id text null,
    use_current_location boolean null default false,
    search_radius integer null default 500,
    "location" geometry (point, 4326) null
  );

create unique index accounts_username_idx on accounts (lower(username));

create index accounts_location_idx on accounts using GIST (location);

create table
  deals (
    id uuid not null default uuid_generate_v4 () primary key,
    dealer_id uuid not null references accounts (id) on delete restrict on update cascade,
    title text not null,
    description text not null,
    category_id integer not null references categories (id) on delete restrict on update cascade,
    "duration" integer not null,
    "start" timestamptz not null,
    "template" boolean not null default false,
    created timestamptz not null default now()
  );

create table
  dealer_ratings (
    user_id uuid not null references accounts (id) on delete restrict on update cascade,
    dealer_id uuid not null references accounts (id) on delete restrict on update cascade,
    stars integer not null,
    rating_text text null,
    created timestamptz not null default now(),
    constraint "dealer_ratings_pk" unique (user_id, dealer_id)
  );

create table
  hot_deals (
    user_id uuid not null references accounts (id) on delete restrict on update cascade,
    deal_id uuid not null references deals (id) on delete restrict on update cascade,
    created timestamptz not null default now(),
    constraint "hot_deals_pk" unique (user_id, deal_id)
  );

create table
  reported_deals (
    reporter_id uuid not null references accounts (id) on delete restrict on update cascade,
    deal_id uuid not null references deals (id) on delete restrict on update cascade,
    reason text not null,
    created timestamptz not null default now(),
    constraint "reported_deals_pk" unique (reporter_id, deal_id)
  );

create table
  favorite_dealers (
    user_id uuid not null references accounts (id) on delete restrict on update cascade,
    dealer_id uuid not null references accounts (id) on delete restrict on update cascade,
    created timestamptz not null default now(),
    constraint "favorite_dealer_pk" unique (user_id, dealer_id)
  );

create table
  likes (
    user_id uuid not null references accounts (id) on delete restrict on update cascade,
    deal_id uuid not null references deals (id) on delete restrict on update cascade,
    created timestamptz not null default now(),
    constraint "likes_pk" unique (user_id, deal_id)
  );

create table
  selected_categories (
    user_id uuid not null references accounts (id) on delete restrict on update cascade,
    category_id integer not null references categories (id) on delete restrict on update cascade,
    created timestamptz not null default now(),
    constraint "selected_categories_pk" unique (user_id, category_id)
  );

-----------------------------------------------------------------------------------------------------------------------
create or replace view
  like_counts_view as
select
  deal_id,
  count(deal_id) as likecount
from
  likes
group by
  deal_id
order by
  likecount desc;

-----------------------------------------------------------------------------------------------------------------------
create or replace view
  dealer_view as
select
  id,
  username,
  street,
  house_number,
  zip,
  city
from
  accounts
where
  dealer is true;

-----------------------------------------------------------------------------------------------------------------------
create or replace view
  active_deals_view as
select
  d.id,
  d.dealer_id,
  d.title,
  d.description,
  d.category_id,
  d.duration,
  d.start,
  a.username,
  a.location,
  c.likecount
from
  deals d
  join accounts a on d.dealer_id = a.id
  left join like_counts_view c on c.deal_id = d.id
where
  d.template = false
  and now() between d."start" and d."start"  + (d."duration" || ' hours')::interval;

-----------------------------------------------------------------------------------------------------------------------
create or replace view
  dealer_ratings_view as
select
  r.user_id,
  r.dealer_id,
  r.stars,
  r.rating_text,
  a.username
from
  dealer_ratings r
  join accounts a on r.user_id = a.id;

-----------------------------------------------------------------------------------------------------------------------
create or replace view
  favorite_dealers_view as
select
  f.user_id,
  f.dealer_id,
  a.username
from
  favorite_dealers f
  join accounts a on f.dealer_id = a.id;

-----------------------------------------------------------------------------------------------------------------------
create
or replace function handle_new_user () returns trigger security definer as $$ 
begin
  insert into
    public.accounts (
      id,
      username,
      email,
      dealer,
      default_category,
      street,
      house_number,
      city,
      zip,
      phone,
      age,
      gender,
      tax_id,
      "location"
    )
  values
    (
      new.id,
      new.raw_user_meta_data ->> 'username',
      new.raw_user_meta_data ->> 'email',
      (new.raw_user_meta_data ->> 'isDealer') :: boolean,
      (new.raw_user_meta_data ->> 'defaultCategory') :: integer,
      new.raw_user_meta_data ->> 'street',
      new.raw_user_meta_data ->> 'houseNumber',
      new.raw_user_meta_data ->> 'city',
      (new.raw_user_meta_data ->> 'zip') :: integer,
      new.raw_user_meta_data ->> 'phone',
      (new.raw_user_meta_data ->> 'age') :: integer,
      new.raw_user_meta_data ->> 'gender',
      new.raw_user_meta_data ->> 'taxId',
      extensions.st_geomfromtext(new.raw_user_meta_data ->> 'location')
    );

return new;

end;

$$ language plpgsql;

-----------------------------------------------------------------------------------------------------------------------
create
or replace function get_favorite_dealers () returns setof record as $$
select
  a.id,
  a.username
from
  accounts a,
  favorite_dealers f
where
  a.id = f.dealer_id
  and f.user_id = auth.uid();

$$ language sql;

-----------------------------------------------------------------------------------------------------------------------
create
or replace function get_favorite_dealer_deals () returns setof record as $$
select
  d. *,
  a.username
from
  deals d
  join favorite_dealers f on d.dealer_id = f.dealer_id
  join accounts a on a .id = d.dealer_id
where
  now() between d. "start"
  and d. "start" + (d. "duration" || ' hours') :: interval
  and f.user_id = auth.uid();

$$ language sql;

-----------------------------------------------------------------------------------------------------------------------
create
or replace function get_active_deals_within_extent (p_location float[] default null, p_radius int default null, p_extent float[] default null) returns setof active_deals_view as $$
declare
  v_point_min geometry(point, 4326);
  v_point_max geometry(point, 4326);
  v_extent geometry(polygon, 4326);
begin
  if p_location is not null and p_radius is not null then
    v_extent := st_buffer(st_point(p_location[1], p_location[2])::geography, p_radius);
  end if;

  if p_extent is not null then
    v_point_min := st_point(p_extent[1], p_extent[2])::geography;
    v_point_max := st_point(p_extent[3], p_extent[4])::geography;
    v_extent := st_envelope(st_makeline(v_point_min, v_point_max));
  end if;

  if v_extent is null then
    raise warning 'Cannot create extent statement: neither location/radius nor extent is given';
  end if;

  return query select * from active_deals_view d where st_within(d.location, v_extent);
end;
$$ language plpgsql;

-----------------------------------------------------------------------------------------------------------------------
create trigger on_auth_user_created
after insert on auth.users for each row
execute procedure handle_new_user ();

alter table accounts enable row level security;

create policy "Select only for own account" on accounts as PERMISSIVE for
select
  to public using (auth.uid () = id)