import { CognitoUserPool, CognitoUser, AuthenticationDetails } from 'amazon-cognito-identity-js';

const poolData = {
  UserPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID,
  ClientId: import.meta.env.VITE_COGNITO_CLIENT_ID,
};

const userPool = new CognitoUserPool(poolData);

/**
 * Authenticates a user against Amazon Cognito.
 * Stores ID token and email in localStorage on success.
 */
export const signIn = (email, password) => {
  return new Promise((resolve, reject) => {
    const authenticationDetails = new AuthenticationDetails({
      Username: email,
      Password: password,
    });

    const userData = {
      Username: email,
      Pool: userPool,
    };

    const cognitoUser = new CognitoUser(userData);

    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: (result) => {
        const idToken = result.getIdToken().getJwtToken();
        const accessToken = result.getAccessToken().getJwtToken();
        
        localStorage.setItem('idToken', idToken);
        localStorage.setItem('accessToken', accessToken);
        localStorage.setItem('email', email);
        
        resolve({ idToken, email });
      },
      onFailure: (err) => {
        reject(err);
      },
    });
  });
};

/**
 * Signs the current user out of Cognito and clears local storage.
 */
export const signOut = () => {
  const cognitoUser = userPool.getCurrentUser();
  if (cognitoUser) {
    cognitoUser.signOut();
  }
  localStorage.clear();
};

/**
 * Returns the current authenticated user's email.
 */
export const getCurrentUser = () => {
  return localStorage.getItem('email');
};

/**
 * Returns the stored Cognito JWT ID Token for Authorization headers.
 */
export const getIdToken = () => {
  return localStorage.getItem('idToken');
};
