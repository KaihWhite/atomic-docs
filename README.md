I reccomend setting up a stop hook with a state check for optimal performance with this skill.
This ensures atomic-docs is loaded only at the most opportune time, and not unnecessarily.
Ask claude to set up a stop hook that checks the diff of the project and only fires if the codebase has changes.
Ensure to tell claude specifially what directories and/or files your codebase consists of.
Do not include your documentation directories as part of the hook state check.
You only want this hook to fire when there are code changes that need to be tracked in the documentation.
This will minimize noise while giving you the best performance of this skill.