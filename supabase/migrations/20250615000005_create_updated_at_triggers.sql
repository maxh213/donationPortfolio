-- Create function to update updated_at column
create or replace function public.update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Create triggers for updated_at columns
create trigger update_profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.update_updated_at_column();

create trigger update_cause_areas_updated_at
  before update on public.cause_areas
  for each row execute procedure public.update_updated_at_column();

create trigger update_charities_updated_at
  before update on public.charities
  for each row execute procedure public.update_updated_at_column();

create trigger update_donations_updated_at
  before update on public.donations
  for each row execute procedure public.update_updated_at_column();