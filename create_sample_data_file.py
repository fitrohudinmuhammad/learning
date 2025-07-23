import pandas as pd
from faker import Faker
import random
from datetime import datetime, timedelta

# Initialize Faker to generate fake data
fake = Faker()

# Generate data for 1 million rows
data = {
    'Name': [fake.unique.name() for _ in range(100000)],
    'Place_of_Date': [fake.city() for _ in range(100000)],
    'Birthday': [(datetime.now() - timedelta(days=random.randint(1, 365)*30)).strftime('%Y-%m-%d') for _ in range(100000)]
}

# Create DataFrame
df = pd.DataFrame(data)

# Save DataFrame to CSV file
df.to_csv('/tmp/sample_data.csv', index=False)
