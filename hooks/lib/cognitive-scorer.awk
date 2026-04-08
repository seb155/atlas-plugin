# cognitive-scorer.awk — Single-pass cognitive state scoring
# Input: lowercased prompt text on stdin
# Variables: plen (prompt length), orig (original prompt with case)
# Output: "fr cu fa fl df cm" (6 space-separated integers)

BEGIN { fr=0; cu=0; fa=0; fl=0; df=0; cm=0 }
{
  line = $0

  # --- Frustration (FR/EN/QC) ---
  # Note: awk char classes don't work with multi-byte UTF-8, so we use alternation
  if (line ~ /(juste fais|just do it|fais-le|do it already|arrete de |arrête de |arrete ca|arrête ça|arrete ça|arrête ca)/) fr += 3
  if (line ~ /(calice|câlice|tabarn|maudit|crisse|osti|ciboire|sacrament)/) fr += 4
  if (line ~ /^(non|no|stop|ugh|nope|pas ça|pas ca)[.!,]*$/) fr += 3
  if (line ~ /(j'ai dit|i said|already told you|je t'ai dit|encore|again[!?])/) fr += 2
  if (plen < 30 && line ~ /(fais|do |fix |change |delete |remove )/) fr += 1

  # --- Curiosity ---
  if (line ~ /(pourquoi|why |explain|explique|how does|comment ca|comment ça)/) cu += 3
  if (line ~ /(what if|et si |interesting|fascinating|tell me more|curieux|curious)/) cu += 2
  if (line ~ /(c'est quoi|what is|qu'est-ce|how come|how would|comment on)/) cu += 2
  if (plen > 80 && orig ~ /\?.*\?/) cu += 2

  # --- Fatigue ---
  if (line ~ /(fatigue|fatigué|tired|exhausted|épuisé|epuise|j.?en peux plus)/) fa += 4
  if (line ~ /(j'arrete|j'arrête|i'm done|enough for|fini pour|bonne nuit|good night|on arrete)/) fa += 3
  if (line ~ /(dernier truc|last thing|one more|un dernier|avant de partir)/) fa += 1

  # --- Flow ---
  n = split(orig, parts, /(```|function |def |class |import |const |let |export )/)
  if (n > 0) cm += n - 1
  if (orig ~ /(\.\/|~\/|\/home\/|src\/|hooks\/|tests\/)/) fl += 1
  if (line ~ /^(\/[a-z-]+|git |make |bun |docker |pytest )/) fl += 2

  # --- Decision fatigue ---
  if (line ~ /^(oui|yes|ok|yep|ouais|yea|sure|d'accord)[.!]*$/) df += 2
  if (line ~ /(whatever|je m'en fous|peu importe|i don't care|choose for me|décide|tu choisis)/) df += 4
  if (line ~ /(go ahead|vas-y|lance|do it|proceed|continue)$/) df += 1
}
END {
  if (cm >= 3) fl += 3
  printf "%d %d %d %d %d %d\n", fr, cu, fa, fl, df, cm
}
