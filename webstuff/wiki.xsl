<?xml version="1.0"?>
<xsl:stylesheet
	       version="1.0"
   	       xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>

<xsl:include href="pod.xsl"/>
<xsl:include href="wikitext.xsl"/>
<xsl:include href="docbook.xsl"/>
<xsl:include href="sidemenu.xsl"/>

<xsl:output method="html"/>

<xsl:param name="action" select="'view'"/>

<xsl:template match="/">
    <html>
      <head>
        <title><xsl:value-of select="/xspwiki/page"/></title>
	<link rel="Stylesheet" href="/stylesheets/wiki.css"
              type="text/css" media="screen" />
      </head>
	
      <body>
       <div class="topbanner">
         Development Wiki
       </div>
       <div class="base">
        <table><tr><td valign="top" width="160">
        <div class="sidemenu">
         <xsl:apply-templates select="document('/sidemenu.xml')" mode="sidemenu"/>
        </div></td><td valign="top" width="80%">
        <div class="maincontent">
         <div class="breadcrumbs">
             <a href="DefaultPage"><xsl:value-of select="/xspwiki/db"/></a> :: <xsl:value-of select="/xspwiki/page"/>
         </div>
         <hr/>
         <div class="content">
          <xsl:choose>
           <xsl:when test="$action='historypage'">
           <h1>History View</h1>
           <div class="ipaddress">IP: <xsl:value-of select="/xspwiki/processing-instruction('ip-address')"/></div>
           <div class="date">Date: <xsl:value-of select="/xspwiki/processing-instruction('modified')"/></div>
           <hr/>
           </xsl:when>
          </xsl:choose>
       
         <xsl:apply-templates/>
        
	<xsl:choose>
	  <xsl:when test="$action='view'">
              <hr/>
	    <a href="./{/xspwiki/page}?action=edit">Edit This Page</a> / <a href="./{/xspwiki/page}?action=history">Show Page History</a>
	  </xsl:when>
	  <xsl:when test="$action='edit'">
              <hr/>
  	    <p><a href="EditTips">EditTips</a></p>
	  </xsl:when>
          <xsl:when test="$action='historypage'">
              <hr/>
          <form action="./{/xspwiki/page}" method="POST">
           <input type="hidden" name="action" value="restore"/>
           <input type="hidden" name="id" value="{$id}"/>
           <input type="submit" name="Submit" value="Restore This Version"/>
          </form>
          </xsl:when>
          <xsl:when test="$action='history'">
              <hr/>
          </xsl:when>
	  <xsl:otherwise>
	  Other Mode?
	  </xsl:otherwise>
	</xsl:choose>

         </div> <!-- content -->	
        </div> <!-- maincontent -->
        </td></tr></table>
       </div> <!-- base -->
      </body>
	
    </html>
</xsl:template>

<xsl:template match="/xspwiki/title"/>
<xsl:template match="/xspwiki/page"/>
<xsl:template match="/xspwiki/db"/>

<xsl:template match="xspwiki">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="edit">
<form action="./{/xspwiki/page}" method="POST" enctype="application/x-www-form-urlencoded">
  <input type="hidden" name="action" value="save"/>
  <h1><xsl:value-of select="/xspwiki/page"/> : 
      <input type="submit" value=" Save "/>
      <input type="submit" name="preview" value=" Preview "/></h1>
  <textarea name="text" style="width:100%" rows="18" cols="80" wrap="virtual">
    <xsl:value-of select="string(./text)"/>
  </textarea>
  <xsl:apply-templates select="./texttypes"/>
</form>
</xsl:template>

<xsl:template match="texttypes">
  Text Type: 
  <select name="texttype">
    <xsl:apply-templates/>
  </select>
</xsl:template>

<xsl:template match="texttype">
  <option value="{@id}">
  <xsl:if test="@selected">
  	  <xsl:attribute name="selected">selected</xsl:attribute>
  </xsl:if>
  	  <xsl:apply-templates/>
  </option>
</xsl:template>

<xsl:template match="history">
  <h1>History for <xsl:value-of select="/xspwiki/page"/></h1>
  <table>
  <tr><th>Date</th><th>IP Address</th><th>Bytes</th></tr>
  <xsl:apply-templates select="./entry"/>
  </table>
</xsl:template>

<xsl:template match="history/entry">
  <tr>
    <xsl:apply-templates/>
  </tr>
</xsl:template>

<xsl:template match="history/entry/id">
</xsl:template>

<xsl:template match="history/entry/modified">
  <td><a href="./{/xspwiki/page}?action=historypage;id={../id}"><xsl:apply-templates/></a></td>
</xsl:template>

<xsl:template match="history/entry/ip-address">
  <td><xsl:apply-templates/></td>
</xsl:template>

<xsl:template match="history/entry/bytes">
  <td><xsl:apply-templates/></td>
</xsl:template>

<xsl:template match="newpage">
  <i>This page has not yet been created</i>
</xsl:template>

<!-- useful for testing - commented out for live
<xsl:template match="node()|@*">
  <xsl:copy>
   <xsl:apply-templates select="@*"/>
   <xsl:apply-templates/>
  </xsl:copy>
</xsl:template>
-->

</xsl:stylesheet>
