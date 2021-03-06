app = (supported) ->
  unless supported instanceof Locales
    supported = new Locales supported
    do supported.index

  (req, res, next) ->
    locales = new Locales req.headers["accept-language"]

    bestLocale = locales.best supported
    req.locale = String bestLocale
    req.rawLocale = bestLocale
    do next

class app.Locale

  # Chrome sends 'zh_TW' (Mandarin as spoken in Taiwan) if you choose
  # 'Chinese Traditional' in the language settings and 'zh_CN' (Mandarin as
  # spoken in China) for 'Chinese Simplified'.
  # If you wish to map those tags to 'zh-HANT' (Traditional) and 'zh-HANS'
  # (Simplified) which are the ISO lang codes, you need some kind of support
  # for CLDR language matching
  # (http://www.unicode.org/reports/tr35/#LanguageMatching) which specifies
  # a mapping algorithm. `@substitutions` is not that support, but is a
  # band-aid for this particular special case.
  @substitutions =
    'zh_TW': 'zh_HANT'
    'zh_CN': 'zh_HANS'

  @default: new Locale process.env.LANG or "en_US"

  constructor: (str) ->
    return unless match = str?.match /[a-z]+/gi

    [language, country] = match

    @code = str
    @language = do language.toLowerCase
    @country  = do country.toUpperCase if country

    normalized = [@language]
    normalized.push @country if @country
    @normalized = normalized.join "_"
    @normalized = Locale.substitutions[@normalized] ? @normalized

  serialize = ->
    if @language
        return @code
    else
        return null

  toString: serialize
  toJSON: serialize

class app.Locales
  length: 0
  _index: null

  sort: Array::sort
  push: Array::push

  constructor: (str) ->
    return unless str

    for item in (String str).split ","
      [locale, q] = item.split ";"

      locale = new Locale do locale.trim
      locale.score = if q then +q[2..] or 0 else 1

      @push locale

    @sort (a, b) -> b.score - a.score

  index: ->
    unless @_index
      @_index = {}
      @_index[locale.normalized] = idx for locale, idx in @

    @_index

  best: (locales) ->
    setLocale = (l) -> # When don't return the default
      r = l
      r.defaulted = false
      return r

    locale = Locale.default
    locale.defaulted = true

    unless locales
      if @[0]
        locale = @[0]
        locale.defaulted = true
      return locale

    index = do locales.index

    for item in @
      normalizedIndex = index[item.normalized]
      languageIndex = index[item.language]

      if normalizedIndex? then return setLocale(locales[normalizedIndex])
      else if languageIndex? then return setLocale(locales[languageIndex])

    locale

  serialize = ->
    [@...]

  toJSON: serialize

  toString: ->
    String do @toJSON

{Locale, Locales} = module.exports = app
