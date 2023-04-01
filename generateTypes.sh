#! /bin/sh
echo Generating Typescript types ...
supabase gen types typescript --local --schema public > $(dirname $0)/../cockaigne-frontend/src/lib/supabase/generated-types.ts
echo DONE
