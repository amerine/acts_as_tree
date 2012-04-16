[![Build Status](https://secure.travis-ci.org/amerine/acts_as_tree.png?branch=master)](http://travis-ci.org/amerine/acts_as_tree)

# ActsAsTree

A gem that extends ActiveRecord to add simple support for organizing items into
parent–children relationships.

## Example

    class Category < ActiveRecord::Base
      include ActiveRecord::Acts::Tree

      acts_as_tree order: "name"
    end

    root      = Category.create("name" => "root")
    child1    = root.children.create("name" => "child1")
    subchild1 = child1.children.create("name" => "subchild1")

    root.parent   # => nil
    child1.parent # => root
    root.children # => [child1]
    root.children.first.children.first # => subchild1

## Compatibility

We no longer support Ruby 1.8 or versions if Rails/ActiveRecord older than 3.0. If you're using a version of ActiveRecord older than 3.0 please use 0.1.1.

Moving forward we will do our best to support the latest versions of ActiveRecord and Ruby.

## Change Log

* 0.2.0 - April 9, 2012
	*  Rails 3 Support
* 0.1.1 - February 3, 2010
	* Bug Fixes
* 0.1.0 - October 9th, 2009
	* First Gem Release

## Note on Patches/Pull Requests

1. Fork the project.
2. Make your feature addition or bug fix.
3. Add tests for it. This is important so we don't break it in a future version
   unintentionally.
4. Commit, do not mess with rakefile, version, or history. (if you want to have
   your own version, that is fine but bump version in a commit by itself so we can
   ignore when we pull)
5. Send us a pull request. Bonus points for topic branches.

## License (MIT)

Copyright (c) 2007 David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the 'Software'), to deal in the
Software without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
