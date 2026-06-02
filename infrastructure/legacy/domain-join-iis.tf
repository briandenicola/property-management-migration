# --- Domain Join the IIS Server ---
# Domain join is performed manually via Bastion after DC promotion completes.
# Use: Add-Computer -DomainName "bjdazure.tech" -Credential (Get-Credential) -Restart
