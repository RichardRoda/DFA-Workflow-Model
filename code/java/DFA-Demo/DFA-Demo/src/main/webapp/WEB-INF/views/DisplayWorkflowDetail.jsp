<%-- 
    Document   : DisplayWorkflowDetail
    Created on : Apr 25, 2015, 12:47:09 AM
    Author     : Richard
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Workflow Detail</title>
    </head>
    <body>
        <h1>Workflow Detail</h1>
        <tiles:insertDefinition name="workflowsTable" >
            <tiles:putAttribute name="dfaWorkflowId" value="${dfaWorkflowId}"/>
            <tiles:putAttribute name="workflows" value="${workflows}"/>
            <tiles:putAttribute name="showActive" value="${true}"/>
        </tiles:insertDefinition>
        <hr/>
        <c:if test="${not empty events}">
        <form:form method="POST" servletRelativeAction="/workflowDetail.htm"  modelAttribute="nextEvent">
            <form:hidden path="employeeId"/>
            <form:hidden path="dfaWorkflowId"/>
            <form:hidden path="dfaStateId"/>
            <table>
                <tr>
                    <td>Event</td>
                    <td><form:select path="eventTyp">
                            <form:option value="" label=""/>
                            <form:options items="${events}" itemValue="eventTyp" itemLabel="eventTx"/>
                        </form:select></td>
                </tr>
                <tr><td colspan="2">Comment:</td></tr>
                <tr><td colspan="2"><form:textarea path="commentTx" rows="10" cols="132"/></td></tr>
                <tr><td colspan="2" align="center"><input type="Submit" value="Save"/></td>
            </table>
        </form:form>
        <hr/>
        </c:if>
        <tiles:insertDefinition name="statesTable">
            <tiles:putAttribute name="states" value="${states}"/>
        </tiles:insertDefinition>
    </body>
</html>
