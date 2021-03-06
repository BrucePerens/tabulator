# tabulator: Alphabetical tabs for the Lucky Framework
Present data organized by alphabetical tabs.

## Simple Usage
Add to shards.yml
```
    tabulator:
      github: BrucePerens/tabulator
```

Include `lib/tabulator/css/style.sass` in your project stylesheet, or copy it in.

In an action, instantiate the tabulator:
```crystal

require "tabulator"
class MyAction < BrowserAction

  get "/companies/:letter" do
    letter = params.get?(:letter)

    t = Tabulator.new(
     # *letter* is the letter corresponding to the tab to present, it will be
     # a path parameter or a URL query parameter.
     letter: letter,

     # This is an Avram query. It can be complicated as necessary to refine the
     # objects to be displayed, but must not be *resolved* (made a complete query
     # which is executed) with a method like `first` or `to_a`. Methods will be
     # added to count the total records, and to restrict the query to only where
     # *field* starts with the requested letter.
     query: CompanyQuery.new,

     # *field* is the name of the field that contains the name of the record
     # which is to be sorted into alphabetical tabs. The provided *query* will
     # be extended to restrict the selected records to those in which *field*
     # starts with a the selected *letter*
     field: :name,

     # Path is the path to this action, minus the selected letter, which will
     # be added to the end of this path. It can be something like "/companies/" 
     # if your route is "/companies/:letter", or "/companies?letter=" if your
     # route is "/companies" and you expect to use a URL query pararameter.
     # In both cases, the parameter name must be the same one provided to the
     # *letter* argument.
     path: "/companies/",

     # *small* is the largest number of total records that should be rendered
     # _without_ tabs, because they would all fit upon one page. If you don't
     # include it, the default is 20.
     small: 20
    )

    # Render your page, providing *html_tabs* which renders the tabs, and
    # *selected*, which is an unresolved Avram query for the selected data.
    # The rest of the work happens in your page.
    html Page::Hierarchy::Companies, html_tabs: t.html_tabs, selected: t.selected
  end
end
```

Do this in your page, and it will render the data separated into alphabetical tabs:
```crystal
  # This resolves the query, so that you can present the data in a list, etc.
  array = selected.to_a
  ul do
    array.each do |a|
      li do
        # Render any information you wish, for each record.
        text a.name
      end
    end
  end
  # This renders the tabs. You can put it at the top and bottom of your data,
  # or either one.
  raw html_tabs
end
```

## Presentation
If the number of total records is smaller than or equal to the *small* argument,
default 20, the whole will be presented in one page, and no tabs will be rendered.

Tabs that would be empty (because they contain no records) are not rendered.

## Nonalphabetical data
A tab bearing the character '#' will be included for all data that doesn't start
with a letter in your alphabet. If you have a lot of data that starts with
digits or other nonalphabetical characters, you can add them to the string
passed to the *alphabet* argument, and each of those characters will get
an individual tab.

## Internationalization
There are two additional arguments to `Tabulator#initialize` for internationalization.
*alphabet* is the alphabet of your user, uppercase, in
alphabetical order (or the order in which you want data presented).
See `Tabulator::English` for an example. The default will be `English` if not
provided.
  
*collate* is the Postgres SQL regional collation string
for the user's language, like `"en_US"`. If this is not set, the default is "POSIX".
