return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`machine_spirit_upgrade` encountered an error loading the Darktide Mod Framework.")

		new_mod("machine_spirit_upgrade", {
			mod_script       = "machine_spirit_upgrade/scripts/mods/machine_spirit_upgrade/machine_spirit_upgrade",
			mod_data         = "machine_spirit_upgrade/scripts/mods/machine_spirit_upgrade/machine_spirit_upgrade_data",
			mod_localization = "machine_spirit_upgrade/scripts/mods/machine_spirit_upgrade/machine_spirit_upgrade_localization",
		})
	end,
	packages = {},
	version = "1.1.0",
}
