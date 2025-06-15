# Supabase Database Migrations

This directory contains the database migration files for the Donation Portfolio project.

## Migration Files

1. **20240101000001_create_profiles_table.sql** - Creates user profiles table linked to auth.users
2. **20240101000002_create_cause_areas_table.sql** - Creates cause areas table for categorizing charities
3. **20240101000003_create_charities_table.sql** - Creates charities table with Cloudinary logo support
4. **20240101000004_create_donations_table.sql** - Creates donations table with proper indexing
5. **20240101000005_create_updated_at_triggers.sql** - Creates triggers for automatic updated_at timestamps

## Running Migrations

To apply these migrations to your Supabase database:

1. Log into your Supabase dashboard
2. Go to the SQL Editor
3. Execute each migration file in order (001 through 005)

Or use the Supabase CLI if you have it configured:

```bash
supabase db push
```

## Schema Features

- **Row Level Security (RLS)** enabled on all tables
- **User data isolation** - users can only access their own data
- **Automatic profile creation** on user signup via Auth0
- **Optimized indexes** for common query patterns
- **Data validation** via check constraints
- **Automatic timestamps** with triggers

## Database Structure

```
auth.users (Supabase built-in)
├── profiles (1:1)
├── cause_areas (1:many)
├── charities (1:many)
│   └── donations (1:many)
```

See DATABASE_SCHEMA_ANALYSIS.md for detailed schema documentation.