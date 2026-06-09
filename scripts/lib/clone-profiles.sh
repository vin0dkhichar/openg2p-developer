#!/usr/bin/env bash
# Map setup profiles to repository keys cloned by scripts/clone-repos.sh.

clone_profile_normalize() {
  local profile="${1:-registry}"
  profile="$(printf '%s' "$profile" | tr '[:upper:]' '[:lower:]')"
  profile="${profile//_/-}"
  case "$profile" in
    nsr) echo "national-social-registry" ;;
    farmer) echo "farmer-registry" ;;
    *) echo "$profile" ;;
  esac
}

clone_profile_list() {
  cat <<'EOF'
Profiles (use with make clone PROFILE=... or make setup PROFILE=...):

  registry                  Shared Registry Gen2 core + Farmer + NSR + sample data
  national-social-registry  NSR only (platform, IAM, AWE, UI, NSR, sample data)
  farmer-registry           Farmer Registry only (platform, IAM, AWE, UI, farmer)
  pbms                      Odoo / PBMS stack only
  bridge                    G2P Bridge only
  spar                      SPAR only
  infra                     No product repos (infra is Docker-only)
  full                      All product repositories
EOF
}

clone_profile_repo_keys() {
  local profile
  profile="$(clone_profile_normalize "${1:-registry}")"

  case "$profile" in
    infra)
      ;;
    farmer-registry)
      echo "registry_platform registry_gen2_staff_portal_ui openg2p_iam awe farmer_registry"
      ;;
    national-social-registry)
      echo "registry_platform registry_gen2_staff_portal_ui openg2p_iam awe national_social_registry openg2p_data"
      ;;
    registry)
      echo "registry_platform registry_gen2_staff_portal_ui openg2p_iam awe farmer_registry national_social_registry openg2p_data"
      ;;
    pbms)
      echo "odoo pbms pbms_community_addons pbms_extensions openg2p_registry odoo_commons"
      ;;
    bridge)
      echo "g2p_bridge"
      ;;
    spar)
      echo "spar"
      ;;
    full)
      echo "odoo pbms pbms_community_addons pbms_extensions openg2p_registry odoo_commons registry_platform registry_gen2_staff_portal_ui openg2p_iam openg2p_data farmer_registry national_social_registry g2p_bridge spar awe"
      ;;
    *)
      echo "Unknown PROFILE '${1}'. Valid profiles:" >&2
      clone_profile_list >&2
      return 1
      ;;
  esac
}
