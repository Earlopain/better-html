module BetterHtml
  class BetterErb
    class Interpolator
      def initialize(parser)
        @parser = parser
      end

      def to_safe_value(value, identifier, auto_escape)

        if @parser.context == :attribute_value
          unless @parser.attribute_quoted?
            raise DontInterpolateHere, "Do not interpolate without quotes around this "\
              "attribute value. Instead of "\
              "<#{@parser.tag_name} #{@parser.attribute_name}=#{@parser.attribute_value}#{identifier}> "\
              "try <#{@parser.tag_name} #{@parser.attribute_name}=\"#{@parser.attribute_value}#{identifier}\">."
          end

          # in a <tag attr="...here..."> we always escape
          CGI.escapeHTML(value.to_s)

        elsif @parser.context == :attribute
          raise DontInterpolateHere, "Do not interpolate without quotes around this "\
            "attribute value. Instead of "\
            "<#{@parser.tag_name} #{@parser.attribute_name}=#{identifier}> "\
            "try <#{@parser.tag_name} #{@parser.attribute_name}=\"#{identifier}\">."

        elsif @parser.context == :tag
          unless value.is_a?(BetterHtml::HtmlAttributes)
            raise DontInterpolateHere, "Do not interpolate in a tag. "\
              "Instead of <#{@parser.tag_name} #{identifier}> please "\
              "try <#{@parser.tag_name} <%= html_attributes(attr: value) %>>."
          end

          value.to_s
        elsif @parser.context == :tag_name
          value = value.to_s
          unless value =~ /\A[a-z0-9\:\-]+\z/
            raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
              "into a tag name around: <#{@parser.tag_name}#{identifier}."
          end

          value
        elsif @parser.context == :rawtext
          value = value.to_s

          if @parser.tag_name.downcase == 'script' &&
              (value =~ /<!--/ || value =~ /<script/i || value =~ /<\/script/i)
            # https://www.w3.org/TR/html5/scripting-1.html#restrictions-for-contents-of-script-elements
            raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
              "into a script tag around: <script>#{@parser.rawtext_text}#{identifier}."
          end

          value
        elsif @parser.context == :comment
          value = value.to_s

          # in a <!-- ...here --> we disallow -->
          if value =~ /-->/
            raise UnsafeHtmlError, "Detected invalid characters as part of the interpolation "\
              "into a html comment around: <!--#{@parser.comment_text}#{identifier}."
          end

          value
        elsif @parser.context == :none
          if value.is_a?(ValidatedOutputBuffer)
            # in html context, never escape a ValidatedOutputBuffer
            value.to_s
          else
            # in html context, follow auto_escape rule
            if auto_escape
              auto_escape_interpolated_argument(value.to_s).html_safe
            else
              value.to_s
            end
          end
        else
          raise InterpolatorError, "Tried to interpolate into unknown location #{@parser.context}."
        end
      end

      private

      def auto_escape_interpolated_argument(arg)
        arg.html_safe? ? arg : CGI.escapeHTML(arg)
      end
    end
  end
end
