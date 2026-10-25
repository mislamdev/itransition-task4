# The deployment on Render

The complete instruction - from the repository to a running application.

The repository already contains everything that Render needs:

| File | What it is |
|---|---|
| `render.yaml` | the blueprint: the database + the web service + all the settings |
| `Procfile` | the start command (the same as in the blueprint) |
| `config/database.yml` | uses `DATABASE_URL` when the platform sets it |
| `config/environments/production.rb` | reads `ASSUME_SSL`, `FORCE_SSL`, `RAILS_SERVE_STATIC_FILES` |

---

## Option A - the blueprint (one click, recommended)

1. **Push the repository** (done):
   `https://github.com/mislamdev/itransition-task4`

2. **In Render:** *New* → **Blueprint** → connect GitHub → select
   `mislamdev/itransition-task4` → **Apply**.

3. Render creates
   - the database **`user-management-db`** (PostgreSQL 16, free) and
   - the service **`user-management`** (Ruby, free),
   links them and starts the first deployment.

4. **Wait for the build** (2–4 minutes: the gems, the assets, the schema, the
   demo data).

5. Render shows the URL of the service, e.g.
   `https://user-management.onrender.com`.

6. **Sign in:** `ada@example.com` / `demo` (226 demo accounts, the data set of
   the task is imported by the seeds).

---

## Option B - manually (if you do not want to use the blueprint)

### 1. The database

*New* → **Postgres** →

| Field | Value |
|---|---|
| Name | `user-management-db` |
| Database | `user_management` |
| User | `user_management` |
| Region | the same as the service |
| PostgreSQL version | 16 |
| Plan | Free |

**Create Database.** Copy the *Internal Database URL* — you need it in step 3.

### 2. The web service

*New* → **Web Service** → connect the repository →

| Field | Value |
|---|---|
| Name | `user-management` |
| Branch | `main` |
| Root directory | *(empty)* |
| Language | Ruby |
| Region | the same as the database |
| Plan | Free |

### 3. The environment variables

*Environment* → **Add Environment Variable**:

| Key | Value |
|---|---|
| `SECRET_KEY_BASE` | *Generate* (the button next to the field) |
| `DATABASE_URL` | the *Internal Database URL* of step 1 |
| `ASSUME_SSL` | `true` |
| `FORCE_SSL` | `false` |
| `RAILS_SERVE_STATIC_FILES` | `true` |
| `RAILS_LOG_LEVEL` | `info` |
| `RUBY_VERSION` | `3.4.2` |

> `SECRET_KEY_BASE` is the secret of the sessions. It is **not** in the
> repository (the repository is public!) - Render generates it for you.

### 4. The build and the start

*Settings* → *Build & Deploy* →

| Field | Value |
|---|---|
| Build Command | `bundle install && bin/rails assets:precompile` |
| Start Command | `bin/rails db:prepare && bundle exec puma -C config/puma.rb` |
| Health Check Path | `/up` |

> **There is no "Pre-Deploy Command" on the free plan** - it is a paid
> feature. The migrations are therefore part of the start command: `db:prepare`
> creates the database and loads the schema at the first deployment (and fills
> the demo data), afterwards it only runs the migrations.
>
> You can leave the *Start Command* empty - the `Procfile` of the repository
> contains exactly the same command.

### 5. Attach the database

*Dashboard* → `user-management` → **Databases** → *Connect Database* →
`user-management-db` → **Connect**.

(If you use the blueprint, this is done automatically.)

### 6. Deploy

*Manual Deploy* → **Deploy latest commit**.

---

## What happens during the first deployment

```
==> Installing dependencies: bundle install
==> Building the assets: bin/rails assets:precompile
==> Starting: bin/rails db:prepare && bundle exec puma -C config/puma.rb
    -- create the database, load the schema, run the migrations
    -- import the 200 accounts of users.json + 26 demo accounts
    -- create the UNIQUE INDEX on the e-mail
==> Listening on http://0.0.0.0:10000
```

The application answers on `https://<your service>.onrender.com`.

---

## How to check that it works

```bash
# 1. the health endpoint (the health check of Render)
curl -i https://<your service>.onrender.com/up        # => HTTP/2 200

# 2. the login form
curl -i https://<your service>.onrender.com/login      # => HTTP/2 200

# 3. the API (it needs a session - the Postman collection does the sign in)
postman collection run postman/user-management.postman_collection.json \
  -e postman/user-management.production.postman_environment.json
```

The collection expects the URL of the deployment in the environment file
(`postman/user-management.production.postman_environment.json` → `baseUrl`).

Locally you can check the configuration of a platform **without** deploying:

```bash
SECRET_KEY_BASE=… DATABASE_URL=… PORT=3201 ASSUME_SSL=true \
  bundle exec puma -C config/puma.rb &
bundle exec ruby script/check_platform.rb       # => 7/7 green
```

---

## Troubleshooting

| The error | The cause | The solution |
|---|---|---|
| `connection to server at "127.0.0.1", port 5432 failed` | `DATABASE_URL` is missing (or it is overridden by the discrete variables) | add `DATABASE_URL` (the *Internal Database URL*) to the environment, or attach the database to the service |
| `ActiveRecord::StatementInvalid: could not find the unique index` | the migrations did not run | the start command must contain `bin/rails db:prepare` (the free plan has no pre-deploy command) |
| `Missing encryption key to decrypt credentials` | `SECRET_KEY_BASE` is missing | add it to the environment (the *Generate* button) - the master key is deliberately **not** in the repository |
| the page is unstyled | the assets were not built / not served | the build command must contain `bin/rails assets:precompile`, the environment `RAILS_SERVE_STATIC_FILES=true` |
| `Bundler::GemNotFound` / the build fails on the gems | Render used Ruby 4.0.5 (the `.ruby-version` of the repository) | set `RUBY_VERSION=3.4.2` in the environment |
| the redirect goes to `http://` | the proxy of Render was not trusted | `ASSUME_SSL=true` |
| the first request takes a minute | the free service sleeps after 15 minutes without a request | expected on the free plan - the paid plan does not sleep |

---

## The free plan

| | |
|---|---|
| the service sleeps | after **15 minutes** without a request, the first request afterwards takes about a minute to wake it up |
| the database expires | after **30 days** Render deletes the free database - the schema and the demo data are rebuilt by the next deployment, the accounts that were created are gone |
| the region | the database and the service have to be in the **same region**, otherwise the application connects over the internet (slower) |

The Starter plan (7 $/month) removes both limitations and adds the
"pre-deploy command" - the migrations could then move back out of the start
command.
