package demo.common;
import org.apache.camel.builder.RouteBuilder;
import org.springframework.stereotype.Component;
@Component
public class CommonTemplate extends RouteBuilder {
 @Override public void configure() {
  routeTemplate("hello-template").templateParameter("label").templateParameter("path")
   .from("platform-http:{{path}}").setBody(simple("route={{label}}"))
   .process(exchange -> exchange.getMessage().setBody(exchange.getMessage().getBody(String.class) + ", pid=" + ProcessHandle.current().pid()));
 }
}