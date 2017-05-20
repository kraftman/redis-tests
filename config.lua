local config = require("lapis.config")

config("development", {
  port = 800
})

config("production", {
  port = 80,
  num_workers = 8,
  code_cache = "on"
})
