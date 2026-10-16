import React from 'react';
import {
  Content,
  ContentHeader,
  Header,
  HeaderLabel,
  Page,
  SupportButton,
} from '@backstage/core-components';
import { Grid } from '@material-ui/core';

type ServiceHealthProps = {
  componentName?: string;
};

export const ServiceHealthCard = (props: ServiceHealthProps) => {
  const { componentName = 'unknown' } = props;

  return (
    <Page themeId="tool">
      <Header title="Service Health" subtitle={`Component: ${componentName}`}>
        <HeaderLabel label="Owner" value="platform-team" />
        <HeaderLabel label="Lifecycle" value="experimental" />
      </Header>
      <Content>
        <ContentHeader title="Status">
          <SupportButton>
            Minimal custom plugin skeleton. Wire up to backend or proxy.
          </SupportButton>
        </ContentHeader>
        <Grid container spacing={3} direction="column">
          <Grid item>
            <p>
              Replace this placeholder with real data fetched via
              <code> discoveryApi </code> + <code> fetchApi </code>, or through
              <code> /api/proxy/service-health </code>.
            </p>
          </Grid>
        </Grid>
      </Content>
    </Page>
  );
};
