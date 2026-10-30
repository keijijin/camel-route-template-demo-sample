package demo.appb;
import org.apache.camel.builder.RouteBuilder;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
@SpringBootApplication(scanBasePackages = {"demo.appb", "demo.common"})
public class Application {
 public static void main(String[] args) { SpringApplication.run(Application.class,args); }
 @Bean RouteBuilder instantiateRoute() {
  return new RouteBuilder() {
   @Override public void configure() {
    templatedRoute("hello-template").routeId("route-b").parameter("label","APP-B").parameter("path","/hello");
   }
  };
 }
}