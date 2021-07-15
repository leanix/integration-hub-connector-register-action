# LeanIX Integration Hub Connector Resgiser Action

This action provides a standard way of registration a connector into the Integration-HUB of all regions.

## Usage

This action reads the connector definition from a file and calls the Integration-Hub to register the provided connector.
Use in advance the provided [leanix/secrets-action](https://github.com/leanix/secrets-action) to inject the required secrets.

A simple provision step in the connector's workflow would look like this:
```yaml
- name: Register connector in Hub
  uses: leanix/integration-hub-connector-register-action@main
  with:
    environment: 'prod'  
```
This reads the file `integration-hub-connecotr-definition.json` from the root of your repository and register it globally on all prod instances of Integration-Hub.
### Input Parameter
| input | required | default | description |
|-------|----------|---------|-------------|
|default_connector_file|no|`integration-hub-connector-definition.json`|The location of the file that contains the definition of the connector that is used as the input for this action.|
|environment|yes|test|The environment to provision to, e.g. test or prod|
|region|no|-|The region to provision to, e.g. westeurope or australiaeast. Leave empty to provision to all regions.|

For the complete structure of the `Connector Definition` file see  in  https://leanix.atlassian.net/wiki/spaces/FLOW/pages/4215773679/Getting+Started 

## Requires
This action requires following GitHub actions in advance:
- [leanix/secrets-action@master](https://github.com/leanix/secrets-action)

## Copyright and license
Copyright 2021 LeanIX GmbH under the [Unlicense license](LICENSE).
