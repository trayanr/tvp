# Evaluation metadata only: keep the selected provider's derivation untouched.
rec {
  tag =
    role: provider:
    if builtins.isAttrs provider && provider ? outPath then
      provider // { __tvpToolRole = role; }
    else
      provider;

  collect =
    providers:
    let
      groups = builtins.foldl' (
        roles: provider:
        if !(builtins.isAttrs provider && provider ? outPath && provider ? __tvpToolRole) then
          roles
        else
          let
            role = provider.__tvpToolRole;
            previous = roles.${role} or [ ];
          in
          if builtins.any (p: p.outPath == provider.outPath) previous then
            roles
          else
            roles // { ${role} = previous ++ [ provider ]; }
      ) { } providers;
      addRole =
        result: role:
        let
          selected = builtins.sort (a: b: a.outPath < b.outPath) groups.${role};
          # Reserve literal role names, including ones that already contain #N.
          freeName =
            attrs: index:
            let
              candidate = "${role}#${toString index}";
            in
            if builtins.hasAttr candidate groups || builtins.hasAttr candidate attrs then
              freeName attrs (index + 1)
            else
              candidate;
        in
        if builtins.length selected == 1 then
          result // { ${role} = builtins.head selected; }
        else
          builtins.foldl' (attrs: provider: attrs // { ${freeName attrs 1} = provider; }) result selected;
    in
    builtins.foldl' addRole { } (builtins.attrNames groups);
}
