create policy "allow all 148yprt_0" on "storage"."objects" as permissive for
select
  to public using ((bucket_id = 'deal-images'::text));

create policy "allow all 148yprt_1" on "storage"."objects" as permissive for insert to public
with
  check ((bucket_id = 'deal-images'::text));

create policy "allow all 148yprt_2" on "storage"."objects" as permissive for
update to public using ((bucket_id = 'deal-images'::text));

create policy "allow all 148yprt_3" on "storage"."objects" as permissive for delete to public using ((bucket_id = 'deal-images'::text));

create policy "allow all vejz8c_0" on "storage"."objects" as permissive for
select
  to public using ((bucket_id = 'profile-images'::text));

create policy "allow all vejz8c_1" on "storage"."objects" as permissive for insert to public
with
  check ((bucket_id = 'profile-images'::text));

create policy "allow all vejz8c_2" on "storage"."objects" as permissive for
update to public using ((bucket_id = 'profile-images'::text));

create policy "allow all vejz8c_3" on "storage"."objects" as permissive for delete to public using ((bucket_id = 'profile-images'::text));

create policy "allow all wgptbg_0" on "storage"."objects" as permissive for
select
  to public using ((bucket_id = 'dealer-images'::text));

create policy "allow all wgptbg_1" on "storage"."objects" as permissive for insert to public
with
  check ((bucket_id = 'dealer-images'::text));

create policy "allow all wgptbg_2" on "storage"."objects" as permissive for
update to public using ((bucket_id = 'dealer-images'::text));

create policy "allow all wgptbg_3" on "storage"."objects" as permissive for delete to public using ((bucket_id = 'dealer-images'::text));