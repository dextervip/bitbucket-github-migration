import requests
from requests.auth import HTTPBasicAuth

username = input('Enter your Bitbucket username: ')
password = input('Enter your Bitbucket app password: ')
workspace = input('Enter your Bitbucket workspace: ')

next_page_url = f'https://api.bitbucket.org/2.0/repositories/{workspace}?pagelen=100&fields=next,values.links.clone.href,values.slug'

repos = []  # New: collect git URLs

while next_page_url:
    response = requests.get(next_page_url, auth=HTTPBasicAuth(username, password))
    if response.status_code != 200:
        print(f"Error: Failed to fetch repositories. Status code: {response.status_code}")
        break
        
    page_json = response.json()
    
    for repo in page_json['values']:
        repo_name = repo['slug']
        # Get the HTTPS clone URL from the list of clone URLs with safe key access
        clone_urls = repo['links']['clone']
        git_clone_url = [url['href'] for url in clone_urls if 'git@' in url['href'] ][0]
        repos.append(git_clone_url)  # Instead of printing, collect the URL
    
    next_page_url = page_json.get('next', None)

# New: Save the git URLs to urls.sh with the bash REPOS array syntax
with open('urls.sh', 'w') as f:
    f.write("REPOS=(\n")
    for url in repos:
        f.write(f'    "{url}"\n')
    f.write(")\n")
