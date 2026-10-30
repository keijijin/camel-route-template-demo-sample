package demo.appb;

import org.apache.camel.CamelContext;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;
import java.util.regex.Pattern;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApplicationIntegrationTest {
 @Autowired CamelContext camelContext;
 @Autowired TestRestTemplate rest;
 @Test void templatedRouteIsRegistered() {
  assertNotNull(camelContext.getRoute("route-b"));
  assertEquals(1, camelContext.getRoutes().size());
 }
 @Test void httpEndpointRespondsWithLabelAndPid() {
  ResponseEntity<String> response = rest.getForEntity("/hello", String.class);
  assertEquals(200, response.getStatusCode().value());
  assertNotNull(response.getBody());
  assertTrue(Pattern.matches("route=APP-B, pid=\\d+", response.getBody()), response.getBody());
 }
 @Test void unknownEndpointReturnsNotFound() {
  assertEquals(404, rest.getForEntity("/not-found", String.class).getStatusCode().value());
 }
}