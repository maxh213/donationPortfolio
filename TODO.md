# Donation Portfolio Project TODO

This TODO list is designed for an AI engineer to work through systematically, completing **exactly one task per development cycle**. Each task should be actionable and completable in a single session.

## Phase 1: Project Foundation & Setup

### Backend Setup (Gleam/Wisp)
- [x] Initialize Gleam project structure with proper dependencies for Wisp web framework
- [x] Set up basic Wisp server with health check endpoint
- [x] Create .env file with environment variables for Supabase, Auth0, and Cloudinary credentials
- [x] Configure environment variables handling to read from .env file
- [x] Create project configuration module for external service connections
- [x] Set up basic error handling and response types for API

### Database Setup (Supabase)
- [x] Analyze database schema requirements and create comprehensive design (see DATABASE_SCHEMA_ANALYSIS.md)
- [x] Create Supabase migration files for the optimized schema:
  - profiles table (linked to auth.users)  
  - cause_areas table (user-owned categories)
  - charities table (user-owned with Cloudinary logo support)
  - donations table (with proper indexing and constraints)
- [x] Implement Row Level Security (RLS) policies for all tables
- [x] Create Gleam database module with Supabase HTTP client
- [x] Implement database query functions for profiles
- [x] Implement database query functions for cause_areas
- [x] Implement database query functions for charities  
- [x] Implement database query functions for donations

## Phase 2: Authentication & User Management

### Auth0/profile Integration
- [ ] This todo.md section was writting by an AI with no context7 access and is probably wrong, think deeply about the following and evaluate if it is correct or needed when designing a auth solution with auth0.
- [x] Set up Auth0 configuration and JWT validation in Gleam
- [x] Create authentication middleware for protecting API routes
- [x] Implement user profile creation/sync with Supabase on first login
- [x] Create API endpoint for user profile retrieval
- [x] Create API endpoint for user profile updates (name, email)
- [x] Create API endpoint for profile picture upload via Cloudinary and saving the url in Supabase
- [x] Create API endpoint for account deletion

## Phase 3: Core API Features

### Charity Management API
- [ ] Create API endpoint for listing all charities (GET /api/charities)
- [ ] Create API endpoint for getting single charity details (GET /api/charities/:id)
- [ ] Create API endpoint for searching charities by name (GET /api/charities/search)
- [ ] Create API endpoint for listing all charities owned by the user (GET /api/charities/user)
- [ ] Create API endpoint for creating new charity (POST /api/charities)
- [ ] Create API endpoint for updating charity (PUT /api/charities/:id)
- [ ] Create API endpoint for deleting charity (DELETE /api/charities/:id)
- [ ] Implement Cloudinary integration for charity logo uploads
- [ ] Add validation for charity data (required fields, URL format, etc.)

### Cause Areas API
- [ ] Create API endpoint for listing all cause areas (GET /api/cause-areas)
- [ ] Create API endpoint for creating new cause area (POST /api/cause-areas)
- [ ] Create API endpoint for updating cause area (PUT /api/cause-areas/:id)
- [ ] Create API endpoint for deleting cause area (DELETE /api/cause-areas/:id)
- [ ] Create API endpoint for assigning charity to cause area (POST /api/charities/:id/cause-areas)
- [ ] Create API endpoint for removing charity from cause area (DELETE /api/charities/:id/cause-areas/:cause_id)
- [ ] Create API endpoint for lising all charities by cause area (GET /api/charities/cause-area/:cause_id)


### Donations API
- [ ] Create API endpoint for listing user's donations (GET /api/donations)
- [ ] Create API endpoint for getting single donation (GET /api/donations/:id)
- [ ] Create API endpoint for creating new donation (POST /api/donations)
- [ ] Create API endpoint for updating donation (PUT /api/donations/:id)
- [ ] Create API endpoint for deleting donation (DELETE /api/donations/:id)
- [ ] Add date range filtering for donations endpoint
- [ ] Add charity filtering for donations endpoint
- [ ] Add cause area filtering for donations endpoint

### Analytics API
- [ ] Create API endpoint for donations by month (GET /api/analytics/monthly)
- [ ] Create API endpoint for donations by year (GET /api/analytics/yearly)
- [ ] Create API endpoint for donations by cause area (GET /api/analytics/cause-areas)
- [ ] Create API endpoint for donation totals and counts (GET /api/analytics/summary)

## Phase 4: Frontend Development (Gleam Static Site)

### Project Setup & Structure
- [ ] look at ../maxh213.github.io for inspiration on project structure and copy that static generation set up exactly, make follow up todo items based on how that project works

### Authentication Pages
- [ ] Use register/login page Auth0
- [ ] Create callback page for Auth0 redirect handling
- [ ] Create logout functionality using Auth0
- [ ] Add authentication state management using Auth0

### Dashboard & Main Layout
- [ ] Create main dashboard layout with navigation
- [ ] Create sidebar navigation component
- [ ] Create header component with user profile
- [ ] Create loading states and error handling components

### Charity Management Frontend
- [ ] Create charities list page with search and filtering
- [ ] Create charity details view page
- [ ] Create add new charity form page
- [ ] Create edit charity form page
- [ ] Implement charity logo upload functionality
- [ ] Add charity deletion confirmation dialog

### Cause Areas Frontend
- [ ] Create cause areas management page
- [ ] Create add/edit cause area forms
- [ ] Create charity-to-cause-area assignment interface

### Donations Frontend
- [ ] Create donations list page with filtering and sorting
- [ ] Create add new donation form page
- [ ] Create edit donation form page
- [ ] Add donation deletion functionality
- [ ] Create date picker component for donation dates
- [ ] Create currency selector component

### Dashboard Visualizations
- [ ] Create monthly donations chart component
- [ ] Create yearly donations chart component
- [ ] Create cause areas breakdown chart component
- [ ] Create summary statistics cards
- [ ] Create responsive chart layouts for mobile

### Account Settings
- [ ] Create account settings page layout
- [ ] Create profile information edit form
- [ ] Create profile picture upload component
- [ ] Create password change functionality
- [ ] Create account deletion confirmation flow

## Phase 5: Integration & Polish

### Data Integration
- [ ] Connect frontend charity management to backend API
- [ ] Connect frontend donations management to backend API
- [ ] Connect frontend cause areas management to backend API
- [ ] Connect frontend dashboard to analytics API
- [ ] Implement proper error handling and user feedback

### User Experience
- [ ] Add form validation and error messages
- [ ] Implement loading spinners and skeleton screens
- [ ] Add success notifications for actions
- [ ] Create responsive design for mobile devices
- [ ] Add keyboard navigation support

### Deployment
- [ ] Set up CI/CD pipeline for github pages hosting and github workflow/actions deployment.

---

## Instructions for AI Engineer

When working on this project:

1. **Review Context:** Always start by reading README.md, TODO.md, and any other .md files to understand current state
2. **Select ONE Task:** Pick the next uncompleted [ ] task from above that can be reasonably completed in one session
3. **State Your Selection:** Clearly announce which specific task you're working on
4. **Implement Only That Task:** Focus exclusively on completing that single task
5. **Test Your Work:** Ask for verification before committing
6. **Commit Changes:** Make a focused commit for just that task
7. **Update TODO:** Mark the completed task with [x] and don't add new unrelated tasks

**Remember:** Complete exactly one task per interaction. Do not plan ahead or work on multiple tasks simultaneously.