# donationPortfolio

MVP Spec: 
- A website to track ones donations each month to various charities. 
- The user should be able to sign up and login using auth0 and it will show them a dashboard.
- The api should store all information in supabase. 
- Once logged in the user should be able to adjust their account settings (name, email, password, delete account, profile picture (use cloudinary and store the url in supabase)).
- The user should be able to add charities they donate to. (This should include, logo (use cloudinary), name, website url, description, and category).
- The user should be able to create cause areas and match charities to cause areas (e.g. animal welfare, global health, education, etc.).
- The user should be able to track their donations by month and year.
- The user should be able to log a donation by currency, amount, date, and match to a charity. 
- The dashboard should display graphs and charts to visualize the donations by month, year, and cause area.

Technology Stack:
- I want to use the exact same front end method and stack as ../maxh213.github.io which is a statically generated front end with gleam and modern CSS methods for a beautiful and clean design.
- The backend should be build with gleam / Wisp for the api, and use supabase, auth0, and cloudinary for everything. Any bit of logic really should be done via the backend, this should be an incredibly lean front end that just displays info via jolt / api calls. 


Future Enhancements (not to be done yet, but to be considered when designing the MVP):
- Add ability to sync with bank accounts and for the user to flag donations so they automatically get imported. Start with Monzo for this. 
- Add ability to export donations to a CSV file.
- Add ability to set donation goals and track progress towards those goals.
- Add ability to add metrics to charities (e.g. per $ how many lives saved, people dewormed, children educated, chickens saved, etc.).
- Add a personal profile page which shows graphs and donations along with the user's name, profile, and a description of their choice which is publically shareable if they enable it. 
- Add a list of recommended charities by the website (Anima International, Fish welfare Initiative, Against Malaria Foundation, etc.) and recommend them to be added with one click. 

## Development Setup

### Prerequisites
- [Gleam](https://gleam.run/getting-started/installing/) installed on your system
- Erlang/OTP (usually installed with Gleam)

### Quick Start with Services Script

Use the provided services script for easy development:

```bash
# Start the backend service
./services.sh start

# Check service status
./services.sh status

# View real-time logs
./services.sh logs

# Run tests
./services.sh test

# Stop the service
./services.sh stop

# Get help
./services.sh help
```

### Manual Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   gleam deps download
   ```

3. Run the development server:
   ```bash
   gleam run
   ```

The API server will start on `http://localhost:8000`

### Available Endpoints

- `GET /` - Welcome page
- `GET /health` - Health check endpoint (returns JSON status)

### Running Tests

```bash
cd backend
gleam test
```

Or use the services script:
```bash
./services.sh test
```

### Environment Variables

- `PORT` - Server port (defaults to 8000)

