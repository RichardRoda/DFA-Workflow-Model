<%-- 
    Document   : AddNewEmployeeProspect
    Created on : Apr 26, 2015, 4:05:28 PM
    Author     : Richard
--%>

<%@page contentType="text/html" pageEncoding="UTF-8"%>
<%@ include file="/jsp/JspHeaderSetup.jsp" %>
<!DOCTYPE html>
<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <title>Add Employee</title>
    </head>
    <body>
        <h1>Add Employee</h1>
        <form:form servletRelativeAction="/addNewEmployeeProspect.htm" modelAttribute="employeeProspect" method="POST">
            <table>
                <tr><td>Last Name<td><td><form:input path="lastNm"/></td></tr>
                <tr><td>First Name<td><td><form:input path="firstNm"/></td></tr>
                <tr><td>Middle Name<td><td><form:input path="middleNm"/></td></tr>
                <tr><td>Street<td><td><form:input path="streetNm"/></td></tr>
                <tr><td>City<td><td><form:input path="cityNm"/></td></tr>
                <tr><td>State<td><td>
                    <form:select path="stateId">
                        <form:option value=''></form:option>
                        <form:option value='1'>AL</form:option>
                        <form:option value='2'>AK</form:option>
                        <form:option value='3'>AZ</form:option>
                        <form:option value='4'>AR</form:option>
                        <form:option value='5'>CA</form:option>
                        <form:option value='6'>CO</form:option>
                        <form:option value='7'>CT</form:option>
                        <form:option value='8'>DE</form:option>
                        <form:option value='9'>DC</form:option>
                        <form:option value='10'>FL</form:option>
                        <form:option value='11'>GA</form:option>
                        <form:option value='12'>HI</form:option>
                        <form:option value='13'>ID</form:option>
                        <form:option value='14'>IL</form:option>
                        <form:option value='15'>IN</form:option>
                        <form:option value='16'>IA</form:option>
                        <form:option value='17'>KS</form:option>
                        <form:option value='18'>KY</form:option>
                        <form:option value='19'>LA</form:option>
                        <form:option value='20'>ME</form:option>
                        <form:option value='21'>MD</form:option>
                        <form:option value='22'>MA</form:option>
                        <form:option value='23'>MI</form:option>
                        <form:option value='24'>MN</form:option>
                        <form:option value='25'>MS</form:option>
                        <form:option value='26'>MO</form:option>
                        <form:option value='27'>MT</form:option>
                        <form:option value='28'>NE</form:option>
                        <form:option value='29'>NV</form:option>
                        <form:option value='30'>NH</form:option>
                        <form:option value='31'>NJ</form:option>
                        <form:option value='32'>NM</form:option>
                        <form:option value='33'>NY</form:option>
                        <form:option value='34'>NC</form:option>
                        <form:option value='35'>ND</form:option>
                        <form:option value='36'>OH</form:option>
                        <form:option value='37'>OK</form:option>
                        <form:option value='38'>OR</form:option>
                        <form:option value='39'>PA</form:option>
                        <form:option value='40'>RI</form:option>
                        <form:option value='41'>SC</form:option>
                        <form:option value='42'>SD</form:option>
                        <form:option value='43'>TN</form:option>
                        <form:option value='44'>TX</form:option>
                        <form:option value='45'>UT</form:option>
                        <form:option value='46'>VT</form:option>
                        <form:option value='47'>VA</form:option>
                        <form:option value='48'>WA</form:option>
                        <form:option value='49'>WV</form:option>
                        <form:option value='50'>WI</form:option>
                        <form:option value='51'>WY</form:option>                           
                </form:select>
                </td></tr>
                <tr><td>Phone<td><td><form:input path="phoneNum"/></td></tr>
                <tr><td>Email<td><td><form:input path="emailAddr"/></td></tr>
                <tr><td>Position<td><td><form:input path="position"/></td></tr>
                <tr><td>Salary<td><td><form:input path="salary"/></td></tr>
                
                <tr><td colspan="2"><input type="Submit" value="Save"/></td></tr>
            </table>
        </form:form>
    </body>
</html>
