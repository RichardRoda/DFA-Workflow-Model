<%-- 
    Document   : DisplayWorkflowList
    Created on : Apr 24, 2015, 9:23:41 AM
    Author     : rodare
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>

<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Active Workflows</title>
    </head>
    <body>
        <h1>Active Workflows</h1>
        <display:table list="${workflows}">
            <display:column property="dfaWorkflowId"/>
            <display:column property="position"/>
            <display:column property="lastNm"/>
            <display:column property="firstNm"/>
            <display:column property="stateAbbr"/>
            <display:column property="active"/>
            <display:column property="workflowTx"/>
            <display:column property="eventTx"/>
            <display:column property="stateTx"/>
            <display:column property="expectedNextEventTx"/>
        </display:table>
    </body>
</html>
