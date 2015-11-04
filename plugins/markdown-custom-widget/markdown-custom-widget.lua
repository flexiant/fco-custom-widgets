--[[
Markdown Custom Widget Provider
© 2015 Flexiant Ltd

This FDL code block defines a custom widget pluggable resource provider that will allow
the creation of widgets containing content defined in markdown format formatted into html

{"FDLINFO":{"NAME":"Markdown Custom Widget","VERSION":"1.0.0"}}
]]

function register()
  return { "markdown_widget_provider" }
end

function markdown_widget_provider()
  local widgetHelper = new("FDLCustomWidgetHelper");

  local pctParams = {};
  table.insert(pctParams, widgetHelper:getRefreshTimeValueDefinition(true));
  table.insert(pctParams, widgetHelper:getResourceDescriptionValueDefinition(true));
  table.insert(pctParams, widgetHelper:getResourceIconValueDefinition(true));

  local actionFunctions = {};
  table.insert(actionFunctions, widgetHelper:getContentActionDefinition("get_content_function", {"BE", "CUSTOMER"}, nil, true));

  return {
    api="PLUGGABLE_PROVIDER",
    version=1,
    ref="markdown_widget_provider",
    name="#__MARKDOWN_WIDGET_NAME",
    description="#__MARKDOWN_WIDGET_DESCRIPTION",
    providerType="MARKDOWN_WIDGET",
    providerGroup="SKYLINE_CUSTOM_WIDGET",
    providerIcon="FONT_ICON_CIRCLE_ARROW_DOWN",
    createFunction={executionFunction="widget_create_function", invocationLevel={"BE"}},
    deleteFunction={executionFunction="widget_delete_function", invocationLevel={"BE"}},
    modifyFunction={executionFunction="widget_modify_function", invocationLevel={"BE"}},
    advertiseFunction={executionFunction="widget_advertise_function"},
    productComponentTypes={
      {
        name="#__MARKDOWN_WIDGET_PCT_DISPLAY_NAME",
        referenceField="MARKDOWN_WIDGET_DISPLAY_PCT",
        optional=false,
        configurableList=pctParams
      },
      {
        name="#__MARKDOWN_WIDGET_PCT_MARKDOWN_NAME",
        referenceField="MARKDOWN_WIDGET_MARKDOWN_PCT",
        optional=true,
        configurableList={
          {
            key="markdown",
            name="#__MARKDOWN_WIDGET_PCT_MARKDOWN_VALUE_NAME",
            description="#__MARKDOWN_WIDGET_PCT_MARKDOWN_VALUE_DESCRIPTION",
            hidden=false,
            readOnly=false,
            required=false,
            dataContent="CODEMIRROR:MARKDOWN",
            validator={
              validatorType="BIG_TEXT"
            }
          }
        }
      }
    },
    actionFunctions=actionFunctions
  }
end

function get_content_function(p)

  local id = "markdown-" .. new("FDLHashHelper"):getRandomUUID();

  local css = ".MarkdownScrollPanel{position: relative; width: 100%; height: 100%; overflow-x: hidden; overflow-y: scroll;}\n.MarkdownPanel{position: relative;left: 5%;width: 90%;}";

  local converter = "https://pagedown.googlecode.com/hg/Markdown.Converter.js";
  --local sanitiser = "https://pagedown.googlecode.com/hg/Markdown.Sanitizer.js";

  local javascript = ""
  .."var onLoadFunction = function() { var container=$(\"#"..id.."\");\n$(container).html(new Markdown.Converter().makeHtml(\""..cleanMarkdown(p.resourceValues.markdown).."\")); }\n\n"
  .."var converterScript = document.createElement(\"script\");\n"
  .."converterScript.src=\""..converter.."\"; \n"
  .."converterScript.setAttribute(\"id\", \"markdown-converter-js\");\n"
  .."converterScript.type=\"text/javascript\"; \n"
  .."converterScript.onload = onLoadFunction;\n"
  .."if (document.getElementById(\"markdown-converter-js\")){\n"
  .."\tonLoadFunction()\n"
  .."}else{"
  .."\tdocument.getElementsByTagName(\"head\").item(0).appendChild(converterScript);\n"
  .."}";

  local html = "<div class=\"MarkdownScrollPanel\"><div class=\"MarkdownPanel\" id=\""..id.."\" /></div>";

  local returnContent = new("FDLCustomWidgetHelper"):createGetContentOutput(css, html, javascript);

  return {
    returnCode = "SUCCESSFUL",
    returnType="STRING",
    returnContent=returnContent
  }
end

function widget_create_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");

  widgetHelper:createIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget_delete_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");

  widgetHelper:deleteIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget_modify_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");

  widgetHelper:modifyIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget_advertise_function(p)
  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function cleanMarkdown(input)
  if (input) then
    input = string.gsub (input, "\n", "\\n");
    input = string.gsub (input, "\r", "\\n");
    input = string.gsub (input, "\"", "\\\"");
  end
  return input;
end