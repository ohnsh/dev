for dji; do
  [ -e "$dji" ] || continue
  bn=$(basename "$dji")
  dn=$(dirname "$dji")
  case "$bn" in
    DJI_??_*)
      bn_s=DJI_${bn#DJI_??_}
      mv -nv "$dji" "$dn/$bn_s"
      ;;
  esac
done
