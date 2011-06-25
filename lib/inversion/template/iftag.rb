#!/usr/bin/env ruby
# vim: set noet nosta sw=4 ts=4 :

require 'inversion/mixins'
require 'inversion/template/attrtag'
require 'inversion/template/containertag'
require 'inversion/template/conditionaltag'


# Inversion 'if' tag.
#
# This tag causes a section of the template to be rendered only if its methodchain or attribute
# is a true value.
#
# == Syntax
#
#   <?if attr ?>...<?end?>
#   <?if obj.method ?>...<?end?>
#
class Inversion::Template::IfTag < Inversion::Template::AttrTag
	include Inversion::Loggable,
	        Inversion::Template::ContainerTag,
	        Inversion::Template::ConditionalTag

	# Inherits AttrTag's tag patterns

	### Render the tag's contents if the condition is true, or any else or elsif sections
	### if the condition isn't true.
	def render( state )
		self.enable_rendering if super
		return self.render_subnodes( state )
	end

	### Render the tag as the body of a comment, suitable for template 
	### debugging.
	### @return [String]  the tag as the body of a comment
	# def as_comment_body
	# end

end # class Inversion::Template::IfTag

