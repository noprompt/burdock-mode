# Burdock

Burdock is an Emacs minor mode for Ruby which provides structured
editing and evaluation operations.

## Installation

Burdock is not available as an official package as of yet so it must
be built from source.

From the command line execute the following or similar commands.

```
$ export BURDOCK_DIRECTORY=~/.emacs.d/lisp/burdock-mode
$ cd $BURDOCK_DIRECTORY
$ git clone https://github.com/noprompt/burdock-mode
$ cd ruby
$ bundle install
```

Next, add the following source to your Emacs configuration wherever
you deem appropriate. Then either evalaute it directly or restart
Emacs.

```el
(add-to-list 'load-path BURDOCK_DIRECTORY)
(require 'burdock-mode)

;; Tells burdoct where the backend Ruby code lives. This can also be
;; configured with `M-x customize-group`.
(setq burdock-ruby-source-directory (concat BURDOCK_DIRECTORY "ruby/"))

;; Enable burdock-mode whenever ruby-mode is also enabled. This is
;; optional but recommended.
(add-hook 'ruby-mode-hook 'burdock-mode)

;; Whenever we initialize burdock-mode we should also start the
;; burdock process.
(add-hook 'burdock-mode-hook 'burdock-start)
```

`BURDOCK_DIRECTORY` here is a string which contains path to the root
of the repository cloned in the first step.

At this point you should now be able to open a Ruby file and begin
using the provided Burdock feature set.

## Usage with `inf-ruby-mode`

One of the primary motivators for the creation of Burdock was the
desired to have structured code evaluation experience complimentary to
what is available in the lisp family of languages. Burdock enables
this functionality by accurately extracting expressions from your Ruby
buffer and sending them to the Ruby process created by `inf-ruby-mode`
for evaluation. When applied judiciously this ability can promote a
much faster feedback loop than the traditional write/run pattern
commonly seen with Ruby development. It is a fantastic compliment
to an automated test runner or other testing tool such as
[`rspec-mode`](https://github.com/pezra/rspec-mode). Finally it is
great way to [poke at things](http://www.posteriorscience.net/?p=206).

To get an appreciation for this start a Ruby process by running
<kbd>M-x</kbd> `run-ruby` or your preferred method then create a new
Ruby buffer with the following code.

```rb
lambda do
  x = 1
  y = 2

  x + y
end.call
```

Now, position your cursor _anywhere_ between the `do` and `end`
delimiters and execute <kbd>M-x</kbd>
`burdock-evaluate-scope-at-point`. With any luck you should see
something similar to the following result in your Ruby REPL.

```
>> lambda do
?>   x = 1
>>   y = 2
>>   x + y
>> end.call
=> 3
```

Voilà!

The only thing left to do is bind this to something easier to type!
