# lua-check-hyphen

## Usage

    \usepackage{lua-check-hyphen}
    ...
    \LuaCheckHyphen{mark,whitelist={filea.txt,fileb.txt}}

## What it does

It lists all hyphenated words in the log file as well as in the file with the extension `.uhy`

## How to use

A typical workflow is:

* run final document
* put the correctly hyphenated words into a text file (format: each word separated with space or on a single line, only whitespace matters as a separator)
* add that file to the whitelist (as given above)
* optionally use the option `mark` to make the unknown hyphenated words visible in the PDF file


Copyright 2012–2017 Patrick Gundlach (patrick@gundla.ch)<br>
Package version: see Makefile<br>
Public repository: https://github.com/pgundlach/lua-check-hyphen<br>
Licensed under the MIT license. See the file 'mit-license.txt' for exact terms.<br>
Status: works fine, slightly unmaintained.<br>
