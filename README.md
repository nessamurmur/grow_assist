# Grow Assist

This is a toy application to help new indoor cannabis growers optimize conditions in their grow tent.

It takes in environmental data and gives about 3 suggestions of
improvements to make, sometimes suggesting relevant products.

Here are it's current limitations:

1. It needs some prompt engineering to give more helpful advice.
Currently, the advice is too generic and it's mostly talking in terms of
VPD. It should instead say things like "It's looking like your
environment is too humid! If you're using a humidifier, try turning it
down. You could also try increasing your exhaust fan speed. If that's
not working, look into getting a humidifier like this one" with a link
included.
2. It's messy. It's a proof of concept. Most of all the action happens
in one file and the tests are fairly limited. Future improvements would
include things like writing some evals that can be regularly run,
refactoring the code to separate the responsibilities a bit better, etc.

I just built this to have a small, few hour project to play with
langchain for a while.

## Setup

`cp .env.example .env` and add an api key for Google AI Studio.
Then:

```
uv sync
uv run fastapi src/main.py
```

## Testing

`uv run pytest src -v`

## Architecture

### API

FastAPI

### Front End

Jinja templates
