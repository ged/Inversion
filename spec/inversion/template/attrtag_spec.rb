#!/usr/bin/env rspec -cfd -b
# vim: set noet nosta sw=4 ts=4 :

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname.parent.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'rspec'
require 'spec/lib/helpers'
require 'inversion/template/attrtag'

describe Inversion::Template::AttrTag do

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end

	describe "parsing" do

		it "can have a simple attribute name" do
			Inversion::Template::AttrTag.new( 'foo' ).name.should == :foo
		end

		it "can have an attribute name and a format string" do
			tag = Inversion::Template::AttrTag.new( '"%0.2f" % foo' )
			tag.name.should == :foo
			tag.format.should == '%0.2f'
		end

		it "raises an exception with an unknown operator" do
			expect {
				Inversion::Template::AttrTag.new( '"%0.2f" + foo' )
			}.to raise_exception( Inversion::ParseError, /expected/ )
		end

		it "raises an exception if it has more than one identifier" do
			expect {
				Inversion::Template::AttrTag.new( '"%0.2f" % [ foo, bar ]' )
			}.to raise_exception( Inversion::ParseError, /expected/ )
		end

		it "supports simple <identifier>.<methodname> syntax" do
			tag = Inversion::Template::AttrTag.new( 'foo.bar' )

			tag.name.should == :foo
			tag.methodchain.should == '.bar'
		end

		it "supports index operator (<identifier>.methodname[ <arguments> ]) syntax" do
			tag = Inversion::Template::AttrTag.new( 'foo.bar[8]' )

			tag.name.should == :foo
			tag.methodchain.should == '.bar[8]'
		end

		it "supports index operator (<identifier>[ <arguments> ]) syntax" do
			tag = Inversion::Template::AttrTag.new( 'foo[8]' )

			tag.name.should == :foo
			tag.methodchain.should == '[8]'
		end

		it "supports <identifier>.<methodname>( <arguments> ) syntax" do
			tag = Inversion::Template::AttrTag.new( 'foo.bar( 8, :baz )' )

			tag.name.should == :foo
			tag.methodchain.should == '.bar( 8, :baz )'
		end

		it "can have a format with a methodchain" do
			tag = Inversion::Template::AttrTag.new( '"%0.02f" % foo.bar( 8 )' )

			tag.name.should == :foo
			tag.methodchain.should == '.bar( 8 )'
			tag.format.should == '%0.02f'
		end
	end

	describe "rendering" do

		it "can render itself as a comment for template debugging" do
			tag = Inversion::Template::AttrTag.new( 'foo.bar( 8, :baz )' )
			tag.as_comment_body.should == "Attr: { template.foo.bar( 8, :baz ) }"
		end

		context "without a format" do

			before( :each ) do
				@tag = Inversion::Template::AttrTag.new( 'foo' )
			end

			it "renders as the stringified contents of the template attribute with the same name" do
				state = Inversion::RenderState.new( :foo => %w[floppy the turtle] )
				@tag.render( state ).should == ["floppy", "the", "turtle"]
			end

			it "doesn't error if the attribute isn't set on the template" do
				state = Inversion::RenderState.new( :foo => nil )
				@tag.render( state ).should == nil
			end

			it "returns false when the rendered value is false" do
				state = Inversion::RenderState.new( :foo => false )
				@tag.render( state ).should equal( false )
			end

			it "can render itself as a comment for template debugging" do
				@tag.as_comment_body.should == 'Attr: { template.foo }'
			end

		end

		context "with a format" do

			before( :each ) do
				@tag = Inversion::Template::AttrTag.new( 'foo' )
				@tag.format = "%0.2f"
			end

			it "renders as the formatted contents of the template attribute with the same name" do
				state = Inversion::RenderState.new( :foo => Math::PI )
				@tag.render( state ).should == '3.14'
			end

			it "doesn't error if the attribute isn't set on the template" do
				pending "recalling why we did this" do
					state = Inversion::RenderState.new( :foo => nil )
					@tag.render( state ).should == nil
				end
			end

			it "can render itself as a comment for template debugging" do
				@tag.as_comment_body.
					should == 'Attr: { template.foo } with format: "%0.2f"'
			end

		end

		context "with a methodchain" do

			before( :each ) do
				@attribute_object = double( "template attribute" )
			end

			it "renders a single method call with no arguments" do
				template = Inversion::Template.new( 'this is <?attr foo.bar ?>' )
				template.foo = @attribute_object
				@attribute_object.should_receive( :bar ).with( no_args() ).and_return( "the result" )

				template.render.should == "this is the result"
			end

			it "renders a single method call with one argument" do
				template = Inversion::Template.new( 'this is <?attr foo.bar(8) ?>' )
				template.foo = @attribute_object
				@attribute_object.should_receive( :bar ).with( 8 ).and_return( "the result" )

				template.render.should == "this is the result"
			end

			it "renders a call with a single index operator" do
				template = Inversion::Template.new( 'lines end with <?attr config[:line_ending] ?>' )
				template.config = { :line_ending => 'newline' }

				template.render.should == "lines end with newline"
			end

			it "renders a single method call with multiple arguments" do
				template = Inversion::Template.new( 'this is <?attr foo.bar(8, :woo) ?>' )
				template.foo = @attribute_object
				@attribute_object.should_receive( :bar ).with( 8, :woo ).and_return( "the result" )

				template.render.should == "this is the result"
			end

			it "renders multiple method calls with no arguments" do
				additional_object = double( 'additional template attribute' )
				template = Inversion::Template.new( 'this is <?attr foo.bar.baz ?>' )
				template.foo = @attribute_object
				template.foo.should_receive( :bar ).and_return( additional_object )
				additional_object.should_receive( :baz ).with( no_args() ).and_return( "the result" )

				template.render.should == "this is the result"
			end

			it "renders multiple method calls with arguments" do
				additional_object = double( 'additional template attribute' )
				template = Inversion::Template.new( 'this is <?attr foo.bar( 8 ).baz( :woo ) ?>' )
				template.foo = @attribute_object
				template.foo.should_receive( :bar ).with( 8 ).and_return( additional_object )
				additional_object.should_receive( :baz ).with( :woo ).and_return( "the result" )

				template.render.should == "this is the result"
			end

			it "renders method calls with template attribute arguments" do
				template = Inversion::Template.new( 'this is <?attr foo.bar( baz ) ?>' )
				foo = double( "foo attribute object" )

				template.foo = foo
				template.baz = 18
				foo.should_receive( :bar ).with( 18 ).and_return( "the result of calling bar" )

				template.render.should == "this is the result of calling bar"
			end
		end

	end

end


