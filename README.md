Pushes metrics about how many GoCD agents are in each state. This only includes agents that have no environment associated with them.

## How to Use
  * Set `GOCD_USERNAME` and `GOCD_PASSWORD` with credentials for a user that has access to the API
  * Make sure your instance has permission to create/put metrics in CloudWatch
  * Run the container. It accesses `localhost:8153` so you'll need host networking if you're just running the container on the master directly:
```
docker run --network=host --userns=host --restart=always -d -e GOCD_USERNAME=${GOCD_USERNAME} -e GOCD_PASSWORD=${GOCD_PASSWORD} -it aarongorka/gocd-metrics:0.0.3
```
