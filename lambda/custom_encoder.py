import json
from decimal import Decimal

class CustomEncoder(json.JSONEncoder):
    """
    Custom JSON encoder for handling Decimal objects.
    """

    def default(self, obj):
        """
        Override the default method to handle Decimal objects.
        
        Converts Decimal objects to float to ensure they can be serialized to JSON.
        """
        if isinstance(obj, Decimal):
            return float(obj)
        # Fallback to the default encoder for other object types
        return super(CustomEncoder, self).default(obj)

