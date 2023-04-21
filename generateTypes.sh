#! /bin/sh
echo Generating Typescript types ...
supabase gen types typescript --local --schema public > $(dirname $0)/../cockaigne-frontend-solidjs/src/lib/supabase/generated-types.ts
echo DONE
