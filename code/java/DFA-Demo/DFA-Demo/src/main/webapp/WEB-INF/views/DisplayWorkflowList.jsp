<%-- 
    Document   : DisplayWorkflowList
    Created on : Apr 24, 2015, 9:23:41 AM
    Author     : rodare
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>
<tiles:importAttribute name="dfaWorkflowId" ignore="true"/>
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Active Workflows</title>
    </head>
    <body>
        <h1>Active Workflows</h1>
        <display:table list="${workflows}" id="row">
             <display:column property="position"/>
            <display:column title="Name">
                <c:if test="${empty dfaWorkflowId or row.dfaWorkflowId != dfaWorkflowId}">
                <a href='<c:url value="/workflowDetail.htm"><c:param name="dfaWorkflowId" value="${row.dfaWorkflowId}"/><c:param name="employeeId" value="${row.employeeId}"/></c:url>'>
                </c:if>
                    ${row.lastNm}, ${row.firstNm}
                <c:if test="${empty dfaWorkflowId or row.dfaWorkflowId != dfaWorkflowId}">
                </a>
                </c:if>
            </display:column>
            <display:column property="stateAbbr" title="State"/>
            <c:if test="${empty query.active}">
                <display:column property="active"/>
            </c:if>
            <display:column property="workflowTx" title="Workflow"/>
            <display:column property="eventTx" title="Previous Event"/>
            <display:column property="stateTx" title="Current Status"/>
            <display:column property="expectedNextEventTx" title="Expected Next Event"/>
        </display:table>
    </body>
</html>
