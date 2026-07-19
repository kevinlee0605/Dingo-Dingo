-- The active daily-reward controller now lives inside StarterGui >
-- Phase3EconomyGui so its behavior is owned alongside the authored UI.
-- Keep this no-op at the legacy StarterPlayerScripts path so a Rojo sync
-- retires the old duplicate without deleting unrelated Team Create scripts.
return
