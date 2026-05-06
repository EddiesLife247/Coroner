-- config.lua
Config = {}

Config.Debug = true
Config.VanModel = 'impermark'
Config.CoronerPeds = { 's_m_m_scientist_01', 's_m_m_doctor_01' }
Config.ReportItem = 'coroner_report'
Config.UseEvidenceIntegration = false -- hook this into your evidence system later
Config.EvidenceScanRadius = 5.0

Config.AllowedJobs = {
    police = true,
    staff = true,
    highways = true,
    ambulance = true,
    fire = true,

}