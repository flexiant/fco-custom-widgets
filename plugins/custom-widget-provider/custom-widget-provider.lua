--[[
Custom Widget Provider
© 2015 Flexiant Ltd

This FDL code block defines a custom widget pluggable resource provider that will allow 
the creation of widgets containing user defined css, html, and javascript

{"FDLINFO":{"NAME":"Custom Widget","VERSION":"1.0.0"}}
]]

function register()
  return { "custom_widget_provider" }
end

function custom_widget_provider()
  local widgetHelper = new("FDLCustomWidgetHelper");

  local displayParams = {};
  table.insert(displayParams, widgetHelper:getRefreshTimeValueDefinition(true));
  table.insert(displayParams, widgetHelper:getResourceDescriptionValueDefinition(true));
  table.insert(displayParams, widgetHelper:getResourceIconValueDefinition(true));

  local actionFunctions = {};
  table.insert(actionFunctions, widgetHelper:getContentActionDefinition("get_content_function", {"BE", "CUSTOMER"}, nil, true));

  return {
    api="PLUGGABLE_PROVIDER",
    version=1,
    ref="custom_widget_provider",
    name="#__CUSTOM_WIDGET_NAME",
    description="#__CUSTOM_WIDGET_DESCRIPTION",
    providerType="CUSTOM_WIDGET",
    providerGroup="SKYLINE_CUSTOM_WIDGET",
    providerIcon="FONT_ICON_VECTOR_PATH_ALL",
    createFunction={executionFunction="widget_create_function", invocationLevel={"BE"}},
    deleteFunction={executionFunction="widget_delete_function", invocationLevel={"BE"}},
    modifyFunction={executionFunction="widget_modify_function", invocationLevel={"BE"}},
    advertiseFunction={executionFunction="widget_advertise_function", invocationLevel={"BE"}},
    productComponentTypes={
      {
        name="#__CUSTOM_WIDGET_PCT_DISPLAY_NAME",
        referenceField="CUSTOM_WIDGET_DISPLAY",
        optional=false,
        configurableList=displayParams
      },
      {
        name="#__CUSTOM_WIDGET_PCT_HTML_NAME",
        referenceField="CUSTOM_WIDGET_HTML",
        optional=true,
        configurableList={
          {
            key="html",
            name="#__CUSTOM_WIDGET_PCT_HTML_VALUE_NAME",
            description="#__CUSTOM_WIDGET_PCT_HTML_VALUE_DESCRIPTION",
            hidden=false,
            readOnly=false,
            required=false,
            dataContent="CODEMIRROR:HTML",
            validator={
              validatorType="BIG_TEXT"
            }
          }
        }
      },
      {
        name="#__CUSTOM_WIDGET_PCT_CSS_NAME",
        referenceField="CUSTOM_WIDGET_CSS",
        optional=true,
        configurableList={
          {
            key="css",
            name="#__CUSTOM_WIDGET_PCT_CSS_VALUE_NAME",
            description="#__CUSTOM_WIDGET_PCT_CSS_VALUE_DESCRIPTION",
            hidden=false,
            readOnly=false,
            required=false,
            dataContent="CODEMIRROR:CSS",
            validator={
              validatorType="BIG_TEXT"
            }
          }
        }
      },
      {
        name="#__CUSTOM_WIDGET_PCT_JAVASCRIPT_NAME",
        referenceField="CUSTOM_WIDGET_JAVASCRIPT",
        optional=true,
        configurableList={
          {
            key="javascript",
            name="#__CUSTOM_WIDGET_PCT_JAVASCRIPT_VALUE_NAME",
            description="#__CUSTOM_WIDGET_PCT_JAVASCRIPT_VALUE_DESCRIPTION",
            hidden=false,
            readOnly=false,
            required=false,
            dataContent="CODEMIRROR:JS",
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
  return { 
    returnCode = "SUCCESSFUL", 
    returnType="STRING", 
    returnContent=new("FDLCustomWidgetHelper"):createGetContentOutput(p.resourceValues.css, p.resourceValues.html, p.resourceValues.javascript) 
  }
end

function widget__create_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  widgetHelper:createIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget__delete_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  widgetHelper:deleteIconBlob(p, false);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget__modify_function(p)
  local widgetHelper = new("FDLCustomWidgetHelper");
  
  widgetHelper:modifyIconBlob(p, true);

  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end

function widget__advertise_function(p)
  return { returnCode = "SUCCESSFUL", returnType="BOOLEAN", returnContent="true" }
end