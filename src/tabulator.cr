require "html_builder"

# This class paginates an Avram query by tabs from A-Z and "#". It's similar
# to Paginator, but for alphabetical tabs.
#
# Tabulator can be used together with Paginator when there are a lot of
# records for a particular alphabetical tab.
#
class Tabulator(T)
  # These are regional alphabets for internationalization. Use a pre-configured one,
  # or provide your own, as a string in alphabetical order, uppercase.
  #
  # I can't just call the English alphabet *Roman*, because some languages
  # add or leave out letters. For example, Italian is missing four that are
  # in Englisb, but they *are* present in borrow-words (including computer
  # technical words, "www" for #example).
  # And of course we have the German Eszet.

  # The pre-defined alphabet for English, this is the default.
  English = "ABCDEFGHIJKLMNOPQRSTUVWXYZ" # Roman alphabet as used in English.

  # For internationalization, the alphabet of your user, uppercase, in
  # alphabetical order (or the order in which you want them presented).
  # See `English` for an example. The default will be `English` if not
  # provided.
  @alphabet : String
  
  # For internationalization, set *collate* to the regional collation string
  # for the user, like `"en_US"`. If this is not set, the default is "POSIX".
  @collate : String = "POSIX"

  # The name of the field that we are tabulating upon. For example, `:name`.
  @field : String|Symbol

  # *letter* is the letter tab currently selected. If this is null or something not
  # in *alphabet*, this will be set to "#" and will show the records for which *field*
  # begins with a nonalphabetical character, if they exist.
  @letter : String

  # The prefix of the path for a tab. The letter of the tab, or *"#"* for
  # records that don't start with a letter, will be added as a suffix to this.
  #
  # * To use path parameters, provide a string like `"/test/"`, which will
  # process to `"/test/#{letter}"` for the path of the tab.
  #
  # * To use query paramters, provide a string like `"/test/?page="`, which
  # will process to `"/test/?page=#{letter}"` for the path of the tab.
  #
  @path = String

  # The maximum number of records that are to be rendered _without_ tabs.
  # There's no point in displaying one letter tab if you only have one record.
  @small : Int32

  #
  # The count of records that would be returned by *query*. This is the sum
  # of the count of an index-only query for each letter in the alphabet, and
  # "#". Because the query only accesses an index, rather than the records,
  # and it returns one integer; it runs relatively quickly.
  getter record_count : Int64

  # An `Array(Char)` containing all of the letters (in uppercase)
  # for which a record exists, independent of case.
  # Use this to write a renderer for your own tabs, rather than
  # use the `html_tabs` method of this class.
  #
  # If the query would return no records, `Tabulator#tabs.size` will be 0.
  # If `Tabulator#tabs.size` is 1, you may wish to take the option of
  # presenting untabbed data in your view.
  #
  # To produce this, an index-only query is run for each letter of the
  #alphabet, and "#", returning a count. Because the query only accesses
  # an index, and not the records, and returns one integer; it runs
  # relatively quicky.
  getter tabs = Array(Char).new(27)

  # The query instance used to get the records to display, including the
  # preloads you will need.
  # Generally it's something like `CompanyQuery.new.preload_url_path`.
  # This must be from `new`, and can have as many criteria to refine the
  # selected records as you choose. For example, if you've set up `pg_trgm`
  # for your database, here's a trigram search:
  # `CompanyQuery.new.where("name % ?", "Colorado").preload_url_path`
  @query : T

  # Create a Tabulator instance. The *letter*, *query* and *path* arguments must be
  # provided, the rest are optional.
  #
  # *letter* is the letter tab currently selected. If this is null or something not
  # in *alphabet*, this will be the first available tab.
  #
  # *query* is the query instance used to get the records to display.
  # Generally it's something like `CompanyQuery.new`. This must be from `new`,
  # and can have as many criteria to refine the selected records as you choose.
  # For example, if you've set up `pg_trgm` for your database, here's a
  # trigram search:
  # `CompanyQuery.new.where("name % ?", "Colorado")`
  #
  # *path* is the prefix of the path for a tab. The letter of the tab,
  # or *"#"* for records that don't start with a letter, will be added
  # as a suffix to this.
  #
  # * To use path parameters, provide a string like `"/test/"`, which will
  # process to `"/test/#{letter}"` for the path of the tab.
  #
  # * To use query paramters, provide a string like `"/test/?page="`, which
  # will process to `"/test/?page=#{letter}"` for the path of the tab.
  #
  # For internationalization, *alphabet* is the alphabet of your user,
  # uppercase, in alphabetical order (or the order in which you want them
  # presented). See `English` for an example.
  # The default will be `English` if not provided.
  #
  # For internationalization, *collate* is the regional collation string for
  # the user, like `"en_US"` or "POSIX". If this is not set, the default is
  # "POSIX".
  #
  def initialize(letter : String?, @query : T, @field : String|Symbol, @path : String, @small : Int32 = 20, @alphabet : String = English, @collate : String = "POSIX") forall T
    count = @query.where("? NOT SIMILAR TO ?", @field, "[#{alphabet.downcase}#{alphabet.upcase}]%").select_count
    @record_count = count
    @tabs << '#'  if count > 0
    alphabet.each_char do |c|
      count = @query.where("? SIMILAR TO ?", @field, "[#{c.downcase}#{c.upcase}]%").select_count
      @record_count += count
      @tabs << c if count > 0
    end
    # *letter* is passed in from the user, so clean it up. It's easy for an extra "?"
    # to be added to the URL, amp-consent can do that. Validating it against
    # the actual populated tabs here should prevent SQL injection attempts.
    # Since we use parameterized queries, they probably would not work anyway.
    #
    # If *letter* doesn't refer to a # populated tab, set it to the first populated tab.
    @letter = (letter || "#").upcase[0,1]
    if @tabs.size > 0 && !@tabs.includes?(@letter.chars[0])
      @letter = @tabs[0].to_s
    end
  end

  # This generates the simplest form of an html list for the tabs.
  # You can provide your own version of this to create a flavor for your
  # particular web toolkit.
  #
  # The user can surround this with another element, perhaps a `div`, and
  # write CSS for styling tags and classes within that element.
  # The `a` tag has the class `content` so that styling for nested lists can
  # be distinguished from styling for the list created here.
  def html_tabs : String

    # Don't render tabs if there are a small number of records.
    return "" if @record_count <= @small

    HTML.build do
      ul class: "tab_row" do
        tabs.each do |c|
          a href: "#{@path}#{c}" do
            if c.to_s == @letter
              li class: "selected" do
                text c.to_s
              end
            else
              li do
                text c.to_s
              end
            end
          end
        end
      end
    end
  end

  # Return an unevaluated query for records in which *field* starts with the
  # letter in *letter*, independent of case. If *letter* is `"#"`, return
  # an unevaluated query of the records in which *field* begins with something
  # else than a letter in *alphabet*. If *letter* doesn't have any data populated,
  # replace it with the first tab that does have data populated.
  #
  # This query can be passed to `paginate` if there are enough records that
  # paginating an alphabetical tab is necessary.
  def selected : Avram::Queryable
    if @record_count <= @small
      # Return all of the records, as the total number of them is small.
      @query
    elsif @letter == "#" # All records in which *field* doesn't start with a letter in *alphabet*
      # Can't use ? for collate, as it passes single-quotes rather than double.
      @query.where("? NOT SIMILAR TO ? ORDER BY ? COLLATE \"#{@collate}\" ASC", @field, "[#{@alphabet.downcase}#{@alphabet.upcase}]%", @field)
    else # All records starting with the given *letter*.
      @query.where("? SIMILAR TO ? ORDER BY ? COLLATE \"#{@collate}\" ASC", @field, "[#{@letter.to_s.downcase}#{@letter.to_s.upcase}]%", @field)
    end
  end
end
