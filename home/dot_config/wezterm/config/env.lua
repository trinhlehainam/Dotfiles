--- @param config Config
return function(config)
  config.set_environment_variables = {
    TERM_PROGRAM = 'WezTerm',
    COLORTERM = 'truecolor',
  }
end
